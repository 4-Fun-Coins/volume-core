// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../interfaces/IEscrow.sol";

/**
    This is a contract used for testing only. If you want to deploy Volume to the 
    Mainnet, please deploy Volume.sol.
 */

contract TestVolume is ERC20, ReentrancyGuard {

    using SafeMath for uint256;

    address owner;

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

    mapping (address => uint256) private userFuelAdded;

    address escrow;

    event REFUEL(address indexed fueler, uint256 indexed amount);
    
    constructor (address escrowAcc) ERC20("Volume", "VOL") {
        owner = _msgSender();
        _mint(_msgSender(), 1000000000*BASE);
        takeoffBlock = block.number * BASE;
        lastRefuel = block.number * BASE;
        fuelTank = 6307200*BASE; // This should be ~1 year on BSC
        escrow = escrowAcc;
    }

    modifier flying(address recipient) {
        // Check the tank
        if (fuelTank == 0){
            // We crashed, the only transfers we allow is to escrow OR from LP pool
            require (recipient == escrow, 'Crashed - please redeem your tokens');
            require (_msgSender() == Escrow(escrow).getLPAddress(), 'Crashed - please redeem your tokens');
        }

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
    function transfer(address recipient, uint256 amount) flying(recipient) public virtual override returns (bool) {

        // Calculate transferAmount and fuel amount
        uint256 fuel = amount * FUEL_AMOUNT / BASE;
        uint256 transferAmount = amount - fuel;

        assert(transferAmount > fuel); // If this is the case, something is very wrong - revert

        /**
            No fees should be applicable if:
                - any escrow interactions
                - any LP interactions
                TODO - make this work
         */
        if (!checkEscrowOrLP(_msgSender()) && !checkEscrowOrLP(recipient)) {
            if (!fly())
                return false; // Crashed

            refuel(amount, fuel, _msgSender());

            _burn(_msgSender(), fuel);
        }

        _transfer(_msgSender(), recipient, transferAmount);
        return true;
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
    function transferFrom(address sender, address recipient, uint256 amount) flying(recipient) public virtual override returns (bool) {

        // Calculate transferAmount and fuel amount
        uint256 fuel = amount * FUEL_AMOUNT / BASE;
        uint256 transferAmount = amount - fuel;

        assert(transferAmount > fuel); // If this is the case, something is very wrong - revert

        if (!checkEscrowOrLP(_msgSender()) && !checkEscrowOrLP(recipient)) {
            if (!fly())
                return false; // Crashed

            refuel(amount, fuel, sender);

            _burn(sender, fuel);
        }

        _transfer(sender, recipient, transferAmount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
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

        refuel(0, fuel, _msgSender());

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
            userFuelAdded[fueler] += integerUserFuel; // Moving full blocks to separate variable for display use
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

    // === Production Functions === //
    function checkEscrowOrLP(address toCheck) internal view returns (bool) {
        // TODO - Change getTestLPAddress to getLP from the escrow function when escrow is deployed
        if (toCheck == escrow || toCheck == getTestLPAddress()) {
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
        return userFuelAdded[account];
    }
    // === End of Production Functions === //

    // === One Time Transfer === // 
    function transferOwnership(address newOwner) external {
        assert (_msgSender() == owner);
        if (!OTT){
            owner = newOwner;
            OTT = true;
        }
    }

    // === Test Functions === //
    function getLastRefuel() external view returns (uint256) {
        return lastRefuel;
    }

    function getPrevFuelTank() external view returns (uint256) {
        return prevFuelTank;
    }

    function getBlocksTravelled() external view returns (uint256) {
        return block.number - lastRefuel;
    }

    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }

    function getFuelPile() external view returns (uint256) {
        return fuelPile;
    }

    function setFuelTank(uint256 newFuel) external {
        fuelTank = newFuel;
    }

    function getEscrowAddress() external view returns (address) {
        return escrow;
    }

    function getLPAddress() external view returns (address) {
        return Escrow(escrow).getLPAddress();
    }

    function getTestLPAddress() internal pure returns (address) {
        return 0xe420279D0bf665073f069cB576c28d6F77633b20; // dummy address 
    }
    // === End of Test Functions === //
}