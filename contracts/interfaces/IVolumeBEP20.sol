// SPDX-License-Identifier: GPLV3
pragma solidity ^0.8.4;

import "../data/structs.sol";

interface IVolumeBEP20 {

    function setLPAddressAsCreditor(address lpPairAddress_) external;

    function setTakeOffBlock(uint256 blockNumber_, uint256 initialFuelTank, string memory milestoneName_) external;

    function addFuelCreditor(address newCreditor_) external;

    function removeFuelCreditor(address creditorToBeRemoved_) external;

    function addFreeloader(address newFreeloader_) external;

    function removeFreeloader(address freeLoaderToBeRemoved_) external;

    function addDirectBurner(address newDirectBurner_) external;

    function removeDirectBurner(address directBurnerToBeRemoved_) external;

    function fly() external returns (bool);

    function directRefuel(uint256 fuel_) external;

    function directRefuelFor(uint256 fuel_, address fuelFor_) external;

    function directBurn(uint256 amount_) external;

    function claimNickname(string memory nickname_) external;

    function getNicknameForAddress(address address_) external view returns (string memory);

    function getAddressForNickname(string memory nickname_) external view returns (address);

    function canClaimNickname(string memory newUserName_) external view returns (bool);

    function changeNicknamePrice(uint256 newPrice_) external;

    function getNicknamePrice() external view returns (uint256);

    function getFuel() external view returns (uint256);

    function getTakeoffBlock() external view returns (uint256);

    function getTotalFuelAdded() external view returns (uint256);

    function getUserFuelAdded(address account_) external view returns (uint256);

    function getAllUsersFuelAdded(uint256 start_, uint end_) external view returns (UserFuel[] memory _array);

    function getAllUsersLength() external view returns (uint256);

    function isFuelCreditor(address potentialCreditor_) external view returns (bool);

    function isFreeloader(address potentialFreeloader_) external view returns (bool);

    function isDirectBurner(address potentialDirectBurner_) external view returns (bool);
}