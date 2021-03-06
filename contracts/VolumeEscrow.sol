// SPDX-License-Identifier: GPLV3
// contracts/VolumeEscrow.sol
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./utils/VolumeOwnable.sol";
import "./token/IBEP20.sol";
import "./token/SafeBEP20.sol";
import "./interfaces/IVolumeBEP20.sol";
import "./interfaces/IVolumeJackpot.sol";
import "./interfaces/IUniSwapRouter.sol";
import "./interfaces/IUniSwapFactory.sol";
import "./interfaces/IUniSwapPair.sol";
import "./interfaces/IVolumeEscrow.sol";

contract VolumeEscrow is VolumeOwnable, ReentrancyGuard, IVolumeEscrow {
    uint256 constant BASE = 10 ** 18;

    using Address for address payable;
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    address public immutable wbnb; // WBNB contract address 
    address public uniRouter;   // uniRouter address (any Uni-Like router)
    address lpPool; // VOL-BNB liq pool 
    address volume; // the Vol token address   
    address volumeJackpot; // volumeJackpot address

    /**
     * allocations for each purpose 
     * 0 => ICO only used for the IDO
     * 1 => LP can only be transferred while creating a Liquidity pool
     * 2 => LP Rewards 
     * 3 => Team 
     * 5 => Marketing
     */
    uint256[] private _allocations;

    // STATE    
    uint8 private _rugpulled = 0;

    uint256 private _totalVolLeft; // VOL tokens left in the users wallets 
    uint256 private _totalBNBLeft; // the BNB amount that was in the BNB

    mapping(address => bool) private _lpCreators;

    /**
     * @dev Constructor.
     */
    constructor(address multisig_, address wbnb_) VolumeOwnable(multisig_) {
        require(wbnb_ != address(0), "wbnb can't be address zero");
        wbnb = wbnb_;
        _lpCreators[multisig_] = true;
    }

    modifier onlyByLPCreators() {
        require(_lpCreators[_msgSender()]);
        _;
    }

    modifier onlyForLPCreation () {
        require(volume != address(0), 'volume is not set yet ');
        require(lpPool == address(0), 'pool is already set');
        require(_allocations[1] > 0, 'no allocation left');
        require(_allocations[1] <= IBEP20(volume).balanceOf(address(this)), 'Allocation is bigger than the balance');
        _;
    }

    /**
     * 
     *  @dev initialize the allocations for the volume bep20 token 
     *  look at the allocation enum to see which index is which
     *  allocations_
     *  0 IDO 
     *  1 LP providing
     *  2 LP Rewards
     *  3 Team
     *  4 Marketing
     *  ["375000000000000000000000000","375000000000000000000000000","100000000000000000000000000","100000000000000000000000000","50000000000000000000000000"],0x511839A0C9676171CF858F52cD1050b22A080CD8
     */
    function initialize(uint256[] memory allocations_, address volumeAddress_) override external onlyOwner {
        require(volumeAddress_ != address(0), "volumeAddress can't be address zero");
        require(allocations_.length == 5, "allocations need to be 5 length");
        require(volume == address(0), "already initialized");
        _allocations = allocations_;

        volume = volumeAddress_;
    }

    /*
    Use this to send VOL from the escrow for a purpose/allocation
    */
    function sendVolForPurpose(uint id_, uint256 amount_, address to_) override external onlyOwner {
        require(id_ != 1, "The liquidity allocation can only be used by the LP creation function");
        require(_allocations[id_] >= amount_, 'VolumeEscrow: amount is bigger than allocation');
        uint currentBalance = IBEP20(volume).balanceOf(address(this));
        require(currentBalance >= amount_, 'amount is more than the available balance');
        // send the amount 
        IBEP20(volume).safeTransfer(to_, amount_);
        _subAllocation(id_, amount_);
    }

    function addLPCreator(address newLpCreator_) override external onlyOwner {
        _lpCreators[newLpCreator_] = true;
    }

    function removeLPCreator(address lpCreatorToRemove_) override external onlyOwner {
        require(lpCreatorToRemove_ != owner(), "can't remove the owner from lp creators");
        _lpCreators[lpCreatorToRemove_] = false;
    }

    /**
        creates LP using WBNB from the sender's balance need to be approved
        can be called by the owner or by any address in the lpCreators mapping
     */
    function createLPWBNBFromSender(uint256 amount_, uint slippage) override external onlyByLPCreators nonReentrant onlyForLPCreation {
        require(amount_ > 0, "amount can't be 0");
        IBEP20(wbnb).safeTransferFrom(_msgSender(), address(this), amount_);

        _createLP(amount_, _allocations[1], slippage);
    }

    /*
        creates LP from this contracts balance slippage percentage will be the ratio slippage_/1000 this allows for setting 0.1% slippage or higher
    */
    function createLPFromWBNBBalance(uint slippage) override external onlyByLPCreators nonReentrant onlyForLPCreation {
        // check the balance
        uint256 wbnbBalance = IBEP20(wbnb).balanceOf(address(this));
        require(wbnbBalance > 0, 'wbnbBalance == 0');

        _createLP(wbnbBalance, _allocations[1], slippage);
    }

    /**
        We use this to transfer any BEP20 that got sent to the escrow
        can't send VOL BNB or LP token 
     */
    function transferToken(address token_, uint256 amount_, address to_) override external onlyOwner {
        require(lpPool != address(0), "VolumeEscrow: Need to initialize and set LPAddress first");
        // removes any early rug pull possibility
        require(token_ != lpPool && token_ != volume && token_ != wbnb, "VolumeEscrow: can't transfer those from here");
        IBEP20(token_).safeTransfer(to_, amount_);
    }

    /**
        Define the Uni like router we are going to use to lock LP
     */

     function setUniLikeRouter(address uniRouter_ ) external onlyOwner{
        require(uniRouter == address(0),'setUniLikeRouter: router already set');
        uniRouter = uniRouter_;
     }

    /**
     * set the LP token manually in case the ICO Team are the ones who creates it after the IDO
     */
    function setLPAddress(address poolAddress_) override external onlyOwner {
        require(volume != address(0), "VolumeEscrow: needs to be initialized first");
        require(poolAddress_ != address(0), "VolumeEscrow: poolAddress_ can't be zero address");
        // if it was set then fail
        require(lpPool == address(0), "VolumeEscrow: LP was already set");
        lpPool = poolAddress_;
        IVolumeBEP20(volume).setLPAddressAsCreditor(lpPool);
    }


    /**
     * set the volumePot address 
     * will be called by the volumeJack pot at deployment
     * and can only be called once so no need to restrict the caller
     */
    function setVolumeJackpot(address volumeJackpotAddress_) override external {
        require(volumeJackpotAddress_ != address(0), "volumeJackpotAddress_ can't be zero address");
        // if it was set then fail
        require(volumeJackpot == address(0), "VolumeEscrow: volumeJackpot was already set");
        volumeJackpot = volumeJackpotAddress_;
    }

    /**
     * Returns the Address where Volume BEP20 was deployed
     */
    function isLPCreator(address potentialLPCreator_) external override view returns (bool) {
        return _lpCreators[potentialLPCreator_];
    }

    /**
     * returns the address for the LP Pair 
     */
    function getLPAddress() override external view returns (address) {
        return lpPool;
    }

    /**
     * Returns the Address where Volume BEP20 was deployed
     */
    function getVolumeAddress() override external view returns (address) {
        return volume;
    }

    /**
     * Returns the Address where Volume BEP20 was deployed
     */
    function getJackpotAddress() override external view returns (address) {
        return volumeJackpot;
    }


    function getAllocation(uint id_) override external view returns (uint256) {
        return _allocations[id_];
    }

    function _subAllocation(uint id_, uint256 amount_) internal {
        _allocations[id_] = _allocations[id_].sub(amount_);
    }

    /**
        Will use the WBNB in this contract balance and The 
    */
    function _createLP(uint256 wbnbAmount_, uint256 volumeAmount_, uint slippage_) internal {
        require(uniRouter != address(0), "_createLP: Router not set");
        lpPool = IUniSwapFactory(IUniSwapRouter(uniRouter).factory()).getPair(volume, wbnb);
        require(lpPool == address(0), '_createLP: already created');

        // Approve the tokens for the uni like router
        IBEP20(wbnb).safeApprove(uniRouter, wbnbAmount_);
        IBEP20(volume).safeApprove(uniRouter, volumeAmount_);

        // Add liquidity 
        IUniSwapRouter(uniRouter).addLiquidity(
            volume,
            wbnb,
            volumeAmount_,
            wbnbAmount_,
            volumeAmount_.mul(1000 - slippage_) / 1000, // slippage /1000 so every 1 in slippage is 0.1%
            wbnbAmount_.mul(1000 - slippage_) / 1000, // slippage /1000 so every 1 in slippage is 0.1%
            address(this),
            block.timestamp + 120000
        );

        // get the pool address 
        lpPool = IUniSwapFactory(IUniSwapRouter(uniRouter).factory()).getPair(volume, wbnb);
        // last check need to get an actual address otherwise it might mean something happened that shouldn't
        require(lpPool != address(0), 'lpPair not created');
        // remove this volume from allocation 
        _subAllocation(1, volumeAmount_);

        // add lp to creditors this will allow users who bought vol to take credit for the fuel generated by that transaction
        IVolumeBEP20(volume).setLPAddressAsCreditor(lpPool);
    }
}

