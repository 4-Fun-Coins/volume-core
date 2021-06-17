// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVolumeEscrow.sol";

contract Volume is ERC20, ReentrancyGuard {

    struct UserFuel {
        address user;
        uint256 fuelAdded;
    }

    using SafeMath for uint256;

    bool OTT;

    uint256 constant BASE = 10**18;

    uint256 constant FUEL_AMOUNT = BASE/10000; // Should be 0.01% when used correctly

    uint256 takeoffBlock; // starting block

    uint256 lastRefuel; // Last pitstop

    uint256 fuelTank; // number of remaining blocks

    uint256 fuelPile;

    uint256 prevFuelTank;

    uint256 totalFuelAdded; // Keep track of all of the additional added blocks


    mapping (address => uint256) private userFuelPile;

    //mapping (address => uint256) private userFuelAdded;
    /**
    Changed this to an array with mapped indexes to make it easy to sort 
    we can retreive a range or a single address from the array 
    we can't get a leader board from the mapping inless we index it off-chain 
    this way we don't have to index it off chain
     */
    mapping (address => uint) private userIndex;
    UserFuel[] userAddedFuel;

    address escrow;

    event REFUEL(address indexed fueler, uint256 indexed amount);

    constructor (address escrowAcc) ERC20("Volume", "VOL") {
        _mint(_msgSender(), 1000000000*BASE); // TODO: mint all supply to escrow in production
        takeoffBlock = block.number * BASE;
        lastRefuel = block.number * BASE;
        fuelTank = 6307200*BASE; // This should be ~1 year on BSC
        require(escrowAcc != address(0), "Volume: escrow can't be address zero"); // 
        escrow = escrowAcc;
        userAddedFuel.push(UserFuel(address(0), 0));
    }

    modifier flying(address sender , address recipient) {
        // Check the tank
        if (fuelTank == 0){
            // We crashed, the only transfers we allow is to escrow OR from LP pool
            require (recipient == escrow || sender == _getLPAddress(), 'Crashed - please redeem your tokens on escrow');
        }
        _;
    }

    /**
     * @dev Throws if called by any account other than the Escrow.
     */
    modifier onlyEscrow() {
        require(escrow == _msgSender(), "Volume BEP20: caller is not the Escrow");
        _;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) flying(_msgSender() , recipient) public virtual override returns (bool) {
        return _volumeTransfer(_msgSender() , recipient , amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) flying(sender , recipient) public virtual override returns (bool) {
        // check allowance 
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "BEP20: transfer amount exceeds allowance");
        // if we get false it means no transfer was made revert
        require(_volumeTransfer(sender , recipient , amount) , "failed to transfer");
        // update allowance
         _approve(sender, _msgSender(), currentAllowance - amount);
        
        return true;
    }

    /**
        This function allows refueling to be done with the full transfer amount.
        All tokens send here will be burned.
     */
    function directRefuel(uint256 fuel) external returns (bool) {
        if (!fly())
            return false; // Crashed

        refuel(fuel /**Make this fuel a bit as efficient as if it was issued by a normal transaction */, fuel, _msgSender()); 

        _burn(_msgSender(), fuel);

        return true;
    }

    function fly() private returns (bool) {
        uint256 blocksTravelled = (block.number * BASE) - lastRefuel;

        prevFuelTank = fuelTank;

        if (blocksTravelled > fuelTank) {
            fuelTank = 0;
            return false;
        } else {
            fuelTank -= blocksTravelled;
            return true;
        }
    }

    function refuel(uint256 transferAmount, uint256 refuelAmount, address fueler) private {
        // Calculate the % of supply that gets refueled
        uint256 fuel = refuelAmount * BASE * BASE / (totalSupply() - transferAmount) / BASE * 300;

        userFuelPile[fueler] += (fuelTank + userFuelPile[fueler]) * fuel / BASE;

        if (userFuelPile[fueler] > BASE) {
            uint256 leftOnUserPile = userFuelPile[fueler] % BASE; //Leaving any fractional blocks on user pile
            uint256 integerUserFuel = userFuelPile[fueler] - leftOnUserPile; // Separating the personally accumulated full blocks from the total pile
            
            uint index = userIndex[fueler];
            if(index <= 0){
                userAddedFuel.push(UserFuel(fueler , 0));
                index = userAddedFuel.length - 1;
                userIndex[fueler] = index; 
                
            }
            userAddedFuel[index].fuelAdded += integerUserFuel;
            //userFuelAdded[fueler] += integerUserFuel; // Moving full blocks to separate variable for display use
            userFuelPile[fueler] = leftOnUserPile; // Resetting user pile to contain only fractional blocks
        }

        fuelPile += (fuelTank + fuelPile) * fuel / BASE;

        if (fuelPile > BASE) {
            uint256 leftOnPile = fuelPile % BASE; // Leaving any fractional blocks on the fuel pile
            uint256 addToFuelTank = fuelPile - leftOnPile; // Separating the accumulated full blocks from the pile
            fuelTank += addToFuelTank; // Adding the accumulated full blocks from the pile to the tank
            totalFuelAdded += addToFuelTank; // Keeping track of the total global fuel added
            fuelPile = leftOnPile; // Resetting the fuel pile so that it only has the fractional blocks
        }

        lastRefuel = block.number * BASE;

        emit REFUEL(fueler, fuel);
    }

    function _volumeTransfer(address sender , address recipient , uint256 amount ) internal returns (bool) {
        
        uint256 transferAmount = amount;


        // TODO : only escrow , becasue probably a lot of volume is going to be generated fron swaping in bakery 
        // if there is no fuel generated fron that it is a big waste 
        // ALSO: When the bakry router is the one sending the fuel should be added to the receiver and not to the router
        /**
            No fees should be applicable if:
                - any escrow in interactions 
                - any LP out transactions // to allow people to widraw LP in case of a crash  
                TODO - make this work
         */
        if (!checkEscrowOrLP(sender) && !checkEscrowOrLP(recipient)) {
            if (!fly())
                return false; // Crashed

            uint256 fuel = amount * FUEL_AMOUNT / BASE;
            transferAmount -= fuel;
            
            // If this is the case, something is very wrong - revert
            assert(transferAmount > fuel);

            refuel(amount, fuel, sender);

            _burn(sender, fuel);
        }

        _transfer(sender, recipient, transferAmount);
        return true;
    }

    /**
        When We crash escrow will be able to burn any left non used allocations
        like marketing allocation , LP rewards and the Vol that was used to provide liquidity
        the only Vol that will stay is the one held by Volume users and they can call the escrow to redeem their
        volume for the underlaying WBNB
     */
    function directBurnFromEscrow(uint256 amount) external onlyEscrow {
        require(!fly());
        _burn(escrow, amount);
    }

    // === Production Functions === //
    function checkEscrowOrLP(address toCheck) internal view returns (bool) {
        if (toCheck == escrow || toCheck == _getLPAddress()) {
            return true;
        }
        return false;
    }

    function getFuel() external view returns (uint256) {
        return fuelTank;
    }

    function getTotalFuelAdded() external view returns (uint256) {
        return totalFuelAdded;
    }

    function getUserFuelAdded(address account) external view returns (uint256) {
        uint index = userIndex[account];
        if(index > 0 )
            return userAddedFuel[index].fuelAdded;
        return 0;
    }

    function getAllUsersFuelAdded(uint256 start , uint end) external view returns (UserFuel[] memory _array) {
        require(start < userAddedFuel.length , 'start is bigger than the length');
        
        if(end >= userAddedFuel.length)
            end = userAddedFuel.length - 1;

        _array = new UserFuel[]( (end + 1) - start);

        for (uint i = start ; i <= end; i++ ) {
            _array[i - start] = userAddedFuel[i];
        }
    }

    function getAllUsersLength() external view returns (uint256) {
        return userAddedFuel.length;
    }

    function _getLPAddress() internal virtual view returns (address) {
        return IVolumeEscrow(escrow).getLPAddress();
    }

    // === End of Production Functions === //


}