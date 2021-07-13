// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVolumeEscrow.sol";
import "./interfaces/IVolumeJackpot.sol";
import './data/structs.sol';


contract Volume is ERC20, ReentrancyGuard {

    using SafeMath for uint256;



    bool OTT;

    uint256 constant BASE = 10**18;

    uint256 constant FUEL_AMOUNT =  BASE / 1000; // Should be 0.1% when used correctly

    uint256 takeoffBlock; // starting block

    uint256 lastRefuel; // Last pitstop

    uint256 fuelTank; // number of remaining blocks

    uint256 totalFuelAdded; // Keep track of all of the additional added blocks

    mapping (address => bool) private _freeloaders; // freeLoaders do not pay fuel on transactions 
    
    // these addresses pay fuel on send but they give credits fro it to the sender 
    // usefull for swap routers and pools and other future NFT market place contracts
    // this makes people who interact with these contracts take credits for the fuel taken from the transaction
    mapping (address => bool) private _fuelCreditors; 

    // direct burners 
    // these addresses can call directBurn to burn from their balances 
    mapping (address => bool) private _directBurners;

    //mapping (address => uint256) private userFuelAdded;
    /**
    Changed this to an array with mapped indexes to make it easy to sort 
    we can retreive a range or a single address from the array 
    we can't get a leader board from the mapping inless we index it off-chain 
    this way we don't have to index it off chain
     */
    mapping (address => uint) private userIndex;

    UserFuel[] userAddedFuel;

    address immutable escrow;

    address immutable multiSig;

    address immutable volumeJackpot;

    uint256 private _nicknamePrice = 2000 * BASE;

    mapping (address => string) private _addressesNicknames;
    mapping (string => address) private _nicknamesAddresses;

    event NICKNAME_CLAIMED(address indexed claimer , string indexed nickname);

    event ADDED_FREELOADER(address indexed freeloader);

    event REFUEL(address indexed fueler, uint256 indexed amount);

    constructor (address escrow_ , address multiSig_,address volumeJackpot_) ERC20("Volume", "VOL") {
        _mint(escrow_, 1000000000*BASE); // TODO: mint all supply to escrow in production
        //takeoffBlock = 0;
        //lastRefuel = 0;
        fuelTank = 2592000*BASE; // This should be 3 months will be changed when the takeoff block is set
        
        require(escrow_ != address(0), "Volume: escrow can't be address zero"); // 
        require(multiSig_ != address(0), "Volume: multiSig_ can't be address zero"); // 
        require(volumeJackpot_ != address(0), "Volume: volumeJackpot_ can't be address zero"); // 
        escrow = escrow_;
        multiSig = multiSig_;
        volumeJackpot = volumeJackpot_;
        
        userAddedFuel.push(UserFuel(address(0), 0));
        _freeloaders[escrow_] = true; // escrow is a freeloader 
        _freeloaders[volumeJackpot_] = true; // jackpot is freeloader is a freeloader 
        _freeloaders[multiSig_] = true; // multisig is free loader
        _freeloaders[address(this)] = true; // volume it self is free loader

        _directBurners[escrow_] = true;
        _directBurners[volumeJackpot_] = true;
    }

    /**
        throws if we aren't flying and the sender isn't LP pr the receiver isn't the escrow
        if we crash LP pool can still send so people can widraw their liquidity but it can no longer receive
        escrow can still receive so people can redeem their VOL for the underlaying WBNB
     */
    modifier flying(address sender_ , address recipient_) {
        if (!_fly()){ // actually make the calculation here and now 
            // We crashed, the only transfers we allow is to escrow OR from LP pool
            require (recipient_ == escrow || sender_ == _getLPAddress(), 'Crashed - please redeem your tokens on escrow');
        }
        _;
    }

    /**
     * @dev Throws if called by any account other specified the caller
     */
    modifier onlyIfCallerIs(address allowedCaller_) {
        require(_msgSender() == allowedCaller_, "Volume: caller is not allowed");
        _;
    }

    function setLPAddressAsCreditor(address lpPairAddress_) onlyIfCallerIs(escrow) external {
        _fuelCreditors[lpPairAddress_] = true;
    }

    function setTakeOffBlock (uint256 blockNumber_ , uint256 initialFuelTank , string memory milestoneName_) external onlyIfCallerIs(multiSig) {
        require(!_tookOff() , "You can only set the takeoffBlock once");
        require(blockNumber_ > block.number , "takeoff need to be in the future");
        takeoffBlock = blockNumber_ * BASE;
        lastRefuel = blockNumber_ * BASE; // this will be the block where 
        fuelTank = initialFuelTank * BASE;
        IVolumeJackpot(volumeJackpot).createMilestone(blockNumber_ , milestoneName_);
    }

    /**
        @dev adds an address to the freeloader, freeloaders are addresses that ignore the fuel function so their transactions don't add fuel
     */
    function addfuelCreditor(address newcreaditor_) external onlyIfCallerIs(multiSig) {
            require(!_freeloaders[newcreaditor_] , "Volume: freeloaders can not be creditors at the same time remove it first");
            _fuelCreditors[newcreaditor_] = true;
    }

    /**
        @dev adds an address to the freeloader, freeloaders are addresses that ignore the fuel function so their transactions don't add fuel
     */
    function removefuelCreditor(address creditorToBeRemoved_) external onlyIfCallerIs(multiSig) {
        require(creditorToBeRemoved_ != _getLPAddress(), "Volume: LP pair shall always be a creditor");
        _fuelCreditors[creditorToBeRemoved_] = false;
    }

    /**
        @dev adds an address to the freeloader, freeloaders are addresses that ignore the fuel function so their transactions don't add fuel
     */
    function addFreeloader(address newfreeloader_) external onlyIfCallerIs(multiSig) {
        require(!_fuelCreditors[newfreeloader_] , "Volume: creditors can not be freeloaders at the same time remove it first");
        _freeloaders[newfreeloader_] = true;
    }

    /**
        @dev adds an address to the freeloader, freeloaders are addresses that ignore the fuel function so their transactions don't add fuel
     */
    function removeFreeloader(address freeLoaderToBeRemoved_) external onlyIfCallerIs(multiSig) {
        require(freeLoaderToBeRemoved_ != escrow && freeLoaderToBeRemoved_ != volumeJackpot && freeLoaderToBeRemoved_ != multiSig, "Volume: escrow, jackpot and multisig will always be a freeloader");
        _freeloaders[freeLoaderToBeRemoved_] = false;
    }


    /**
        @dev adds an address to the freeloader, freeloaders are addresses that ignore the fuel function so their transactions don't add fuel
     */
    function addDirectBurner(address newDirectBurner_) external onlyIfCallerIs(multiSig) {
        _directBurners[newDirectBurner_] = true;
    }

    /**
        @dev adds an address to the freeloader, freeloaders are addresses that ignore the fuel function so their transactions don't add fuel
     */
    function removeDirectBurner(address directBurnerToBeRemoved_) external onlyIfCallerIs(multiSig) {
        require(directBurnerToBeRemoved_ != escrow && directBurnerToBeRemoved_ != volumeJackpot, "Volume: escrow and jackpot will always be a direct burner");
        _directBurners[directBurnerToBeRemoved_] = false;
    }

    function fly() external {
        _fly();
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient_` cannot be the zero address.
     * - the caller must have a balance of at least `amount_`.
     */
    function transfer(address recipient_, uint256 amount_) flying(_msgSender() , recipient_) public virtual override returns (bool) {
        if(!_tookOff()){ // if we did not launch yet behave like a normal BEP20
            _transfer(_msgSender(), recipient_, amount_);
            return true;
        }
        
        return _volumeTransfer(_msgSender() , recipient_ , amount_);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender_` and `recipient_` cannot be the zero address.
     * - `sender_` must have a balance of at least `amount_`.
     * - the caller must have allowance for ``sender_``'s tokens of at least
     * `amount_`.
     */
    function transferFrom(address sender_, address recipient_, uint256 amount_) flying(sender_ , recipient_) public virtual override returns (bool) {
        // check allowance 
        uint256 currentAllowance = allowance(sender_, _msgSender());
        require(currentAllowance >= amount_, "BEP20: transfer amount exceeds allowance");
        
        if(!_tookOff()) // if we did not launch yet behave like a normal BEP20
            _transfer(sender_, recipient_, amount_);
        else
            // if we get false it means no transfer was made revert
            require(_volumeTransfer(sender_ , recipient_ , amount_) , "failed to transfer");
        
        // update allowance
         _approve(sender_, _msgSender(), currentAllowance - amount_);

        return true;
    }

    /**
        This function allows refueling to be done with the full transfer amount.
        All tokens send here will be burned.
     */
    function directRefuel(uint256 fuel_) external{
        require(_tookOff() , "Volume: You can't fuel before take off");
        require(_fly() , "Volume: We crashed can't fuel any more");

        _refuel(_msgSender(), _msgSender(), fuel_ ); 
    }

    /*
        Same as directRefuel but credits the fuel to the @fuelFor_
    */ 
    function directRefuelFor(uint256 fuel_, address fuelFor_) external{
        require(_tookOff() , "Volume: You can't fuel before take off");
        require(_fly() , "Volume: We crashed can't fuel any more");

        _refuel(_msgSender(), fuelFor_, fuel_ );
    }

    /**
        When We crash escrow will be able to burn any left non used allocations
        like marketing allocation , LP rewards and the Vol that was used to provide liquidity
        the only Vol that will stay is the one held by Volume users and they can call the escrow to redeem their
        volume for the underlaying WBNB

        Also when users submit a nikname for themselves escrow will burn the nikname price
     */
    function directBurn(uint256 amount_) external {
        require(_directBurners[_msgSender()] , "Volume: only direct burners");
        _burn(_msgSender(), amount_);
    }

    /**
        Claims a nikname for a the caller , niknake has to be unique
        the price of the nickname is 
     */
    function claimNickname (string memory nikname_) external {
        require(_tookOff() , 'Volume: we are not flying yet');
        require(_fly() , "Volume: we crashed you can't claim nickname now");
        require(_nicknamesAddresses[nikname_] == address(0) , "Nickname already claimed");
        require(bytes(nikname_).length > 0, "Volume: user name can't be empty string");

        // use the price of the nickname to refuel
        _refuel(_msgSender(), _msgSender(), _nicknamePrice);
        
        // unclaim old nickname
        string memory oldName = _addressesNicknames[_msgSender()];
        if(bytes(oldName).length != 0)
            _nicknamesAddresses[oldName] = address(0);

        _addressesNicknames[_msgSender()] = nikname_;
        _nicknamesAddresses[ nikname_] = _msgSender();

        emit NICKNAME_CLAIMED(_msgSender() , nikname_);
    }

    /**
        returns the nickname linked the the given address
    */
    function getNicknameForAddress (address address_) external view returns (string memory)  {
        return _addressesNicknames[address_];
    }

    /**
        returns the address linked the the given nickname
     */
    function getAddressForNickname (string memory nickname_) external view returns (address ) {
        return _nicknamesAddresses[nickname_];
    }

    /*
        returns true if a nickname is available and ready to be claimed
    */
    function canClaimNickname (string memory newUserName_) external view returns (bool) {
        return _nicknamesAddresses[newUserName_] == address(0);
    }

    /**
        Sets a new price for nickname claiming
     */
    function changeNicknamePrice (uint256 newPrice_) onlyIfCallerIs(multiSig) external {
        _nicknamePrice = newPrice_;
    }

    function getNicknamePrice () external view returns(uint256) {
        return _nicknamePrice;
    }

    function getFuel() external view returns (uint256) {
        return fuelTank;
    }

    function getTakeoffBlock () external view returns (uint256){
        return takeoffBlock;
    }

    function getTotalFuelAdded() external view returns (uint256) {
        return totalFuelAdded;
    }

    function getUserFuelAdded(address account_) external view returns (uint256) {
        uint index = userIndex[account_];
        if(index > 0 )
            return userAddedFuel[index].fuelAdded;
        return 0;
    }

    function getAllUsersFuelAdded(uint256 start_ , uint end_) external view returns (UserFuel[] memory _array) {
        require(start_ < userAddedFuel.length , 'start is bigger than the length');
        
        if(end_ >= userAddedFuel.length)
            end_ = userAddedFuel.length - 1;

        _array = new UserFuel[]( (end_ + 1) - start_);

        for (uint i = start_ ; i <= end_; i++ ) {
            _array[i - start_] = userAddedFuel[i];
        }
    }

    function getAllUsersLength() external view returns (uint256) {
        return userAddedFuel.length;
    }

    function isFuelCreditor(address potentialCreditor_) external view returns (bool){
        return _fuelCreditors[potentialCreditor_];
    }

    function isFreeloader(address potentialFreeloader_) external view returns (bool){
        return _freeloaders[potentialFreeloader_];
    }

    function isDirectBurner(address potentialDirectBurner_) external view returns (bool){
        return _directBurners[potentialDirectBurner_];
    }

    /**
        Will use fuel from the tank to cover the blocks we flied from last time
     */
    function _fly() private returns (bool) {
        if(!_tookOff()) return true; // we did not take off yet

        uint256 blocksTravelled = (block.number * BASE) - lastRefuel;

        if (blocksTravelled/BASE > fuelTank/BASE) { //fractions of a block won't count
            fuelTank = 0;
            return false;
        } else {
            fuelTank -= blocksTravelled;
            lastRefuel = block.number * BASE;
            return true;
        }
    }

    function _refuel(address deductedFrom_, address fueler_, uint256 refuelAmount_) private {
        if(!_fly()){
            // if we crashed burn all alloccation (this will only trigger from people widrawing liquidity from LP pool)
            _burn(deductedFrom_ , refuelAmount_);
            return;
        }
        require(!_freeloaders[fueler_], "Volume: freeloaders can not take credit for fuel");
        require(!_fuelCreditors[fueler_], "Volume: fuelCreditors can not take credit for fuel");

        uint volumeToBeBurned = refuelAmount_ / 2; // half is burned and the other half is sent to jackpot
        // Calculate the % of supply that gets refueled
        uint256 fuel = volumeToBeBurned.mul(BASE).mul(BASE) / (totalSupply() - volumeToBeBurned) / BASE * 300;

        uint256 fuelToBeAdded = fuelTank * fuel / BASE;
        uint index = userIndex[fueler_];
        if(index <= 0){
            userAddedFuel.push(UserFuel(fueler_ , 0));
            index = userAddedFuel.length - 1;
            userIndex[fueler_] = index; 
        }
        userAddedFuel[index].fuelAdded += fuelToBeAdded;
        fuelTank += fuelToBeAdded; // Adding the accumulated full blocks from the pile to the tank
        totalFuelAdded += fuelToBeAdded;
        
        _burn(deductedFrom_, volumeToBeBurned); // burn the fuel 

        uint256 volumeToPot = refuelAmount_ - volumeToBeBurned; // prevents any precision loss
        _transfer(deductedFrom_, address(this), volumeToPot); // transfer the amount to volume
        _approve(address(this), volumeJackpot, volumeToPot); // approve the jackpot contact to spend 
        IVolumeJackpot(volumeJackpot).deposit(volumeToPot, fuelToBeAdded, fueler_); // call deposit for the fueler , this will add the vol to the jackpot and adds this amount to this user's participation

        emit REFUEL(fueler_, fuel);
    }

    function _volumeTransfer(address sender_ , address recipient_ , uint256 amount_ ) internal returns (bool) {
        
        uint256 transferAmount = amount_;

        if(!_freeloaders[sender_] && !_freeloaders[recipient_]) {
            // pay fuel
            uint256 fuel = amount_ * FUEL_AMOUNT / BASE;
            transferAmount -= fuel;
            
            // If this is the case, something is very wrong - revert
            assert(transferAmount > fuel);
            if(sender_ != _getLPAddress() && !_fuelCreditors[sender_] ) // pays fuel and credits to the sender 
                _refuel(sender_, sender_, fuel);
            else  // pays fuel but gives credit for it to the receipient 
                _refuel(sender_, recipient_, fuel); // if the LP is the sender then add this fuel to who ever swapped wbnb for VOL
        }

        _transfer(sender_, recipient_, transferAmount);
        return true;
    }

    function _getLPAddress() internal virtual view returns (address) {
        return IVolumeEscrow(escrow).getLPAddress();
    }

    function _tookOff() internal view returns (bool) {
        return takeoffBlock != 0 && takeoffBlock <= block.number * BASE;
    }
}