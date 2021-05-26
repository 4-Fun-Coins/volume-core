// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TestVolume is ERC20 {

    using SafeMath for uint256;

    address owner;

    uint256 constant BASE = 10**18;

    uint256 constant FUEL_AMOUNT = BASE/10000; // Should be 0.01% when used correctly

    uint256 takeoffBlock; // starting block

    uint256 lastRefuel; // Last pitstop

    uint256 fuelTank; // number of remaining blocks

    uint256 fuelPile;

    uint256 prevFuelTank;
    
    constructor () ERC20("Volume", "VOL") {
        owner = _msgSender();
        _mint(_msgSender(), 1000000*BASE);
        takeoffBlock = block.number * BASE;
        lastRefuel = block.number * BASE;
        fuelPile = 0;
        fuelTank = 6307200*BASE; // This should be ~1 year on BSC
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {

        // Check the tank
        if (fuelTank == 0)
            return crashAndBurn(amount);
        
        // Calculate transferAmount and fuel amount
        uint256 fuel = amount * FUEL_AMOUNT / BASE;
        uint256 transferAmount = amount - fuel;

        assert(transferAmount > fuel); // If this is the case, something is very wrong - revert

        if (!fly())
            return false; // Crashed

        refuel(fuel);

        _burn(_msgSender(), fuel);
        //

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
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        // Check the tank
        if (fuelTank == 0)
            return crashAndBurn(amount);

        // Calculate transferAmount and fuel amount
        uint256 fuel = amount * FUEL_AMOUNT / BASE;
        uint256 transferAmount = amount - fuel;

        assert(transferAmount > fuel); // If this is the case, something is very wrong - revert

        if (!fly())
            return false; // Crashed

        refuel(fuel);

        _burn(_msgSender(), fuel);
        //

        _transfer(sender, recipient, transferAmount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function crashAndBurn(uint256 amount) private returns (bool) {
        _burn(_msgSender(), amount);

        return false;
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

    function refuel(uint256 refuelAmount) private {
        // Calculate the % of supply that gets refueled
        uint256 fuel = refuelAmount * BASE * BASE / totalSupply() / BASE;

        fuelPile += (fuelTank + fuelPile) * fuel / BASE;

        if (fuelPile > BASE) {
            uint256 leftOnPile = fuelPile % BASE;
            uint256 addToFuelTank = fuelPile - leftOnPile;
            fuelTank += addToFuelTank;
            fuelPile = leftOnPile;
        }

        lastRefuel = block.number * BASE;
    }

    function getFuel() external view returns (uint256) {
        return fuelTank;
    }

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
}