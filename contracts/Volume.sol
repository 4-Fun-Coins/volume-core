// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Volume is ERC20 {

    using SafeMath for uint256;

    address owner;

    uint256 constant BASE = 10**18;

    uint256 constant FUEL_AMOUNT = BASE/10000; // Should be 0.01% when used correctly

    uint256 lastRefuel; // Last pitstop

    uint256 fuelTank; // number of remaining blocks

    uint256 fuelPile;
    
    constructor () ERC20("Volume", "VOL") {
        owner = _msgSender();
        _mint(_msgSender(), 1000000*BASE);
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
            return false; // Crashed
        
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
            return false; // Crashed

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

    function fly() private returns (bool) {
        uint256 blocksTravelled = (block.number * BASE) - lastRefuel;

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

    function getFuelPile() external view returns (uint256) {
        return fuelPile;
    }

    function getFuelTank() external view returns (uint256) {
        return fuelTank;
    }
}