// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.24;

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param _a The multiplicand
    /// @param _b The multiplier
    /// @param _denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 _a,
        uint256 _b,
        uint256 _denominator
    )
        internal
        pure
        returns (uint256 result)
    {
        // 512-bit multiply [prod1 prod0] = a * b
        // Compute the product mod 2**256 and mod 2**256 - 1
        // then use the Chinese Remainder Theorem to reconstruct
        // the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2**256 + prod0
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(_a, _b, not(0))
            prod0 := mul(_a, _b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(_denominator > 0);
            assembly {
                result := div(prod0, _denominator)
            }
            return result;
        }

        // Make sure the result is less than 2**256.
        // Also prevents _denominator == 0
        require(_denominator > prod1);

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        // Compute remainder using mulmod
        uint256 remainder;
        assembly {
            remainder := mulmod(_a, _b, _denominator)
        }
        // Subtract 256 bit number from 512 bit number
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of _denominator
        // Compute largest power of two divisor of _denominator.
        // Always >= 1.
        uint256 twos;
        assembly {
            // Perform the NOT operation, equivalent to bitwise negation
            let negated := not(_denominator)

            // Add 1 to get the two's complement (equivalent to negation in this context)
            negated := add(negated, 1)

            // Perform the AND operation with the original _denominator
            twos := and(negated, _denominator)
        }
        // Divide _denominator by power of two
        assembly {
            _denominator := div(_denominator, twos)
        }

        // Divide [prod1 prod0] by the factors of two
        assembly {
            prod0 := div(prod0, twos)
        }
        // Shift in bits from prod1 into prod0. For this we need
        // to flip `twos` such that it is 2**256 / twos.
        // If twos is zero, then it becomes one
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert _denominator mod 2**256
        // Now that _denominator is an odd number, it has an inverse
        // modulo 2**256 such that _denominator * inv = 1 mod 2**256.
        // Compute the inverse by starting with a seed that is correct
        // correct for four bits. That is, _denominator * inv = 1 mod 2**4
        uint256 inv = (3 * _denominator) ^ 2;
        // Now use Newton-Raphson iteration to improve the precision.
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step.
        inv *= 2 - _denominator * inv; // inverse mod 2**8
        inv *= 2 - _denominator * inv; // inverse mod 2**16
        inv *= 2 - _denominator * inv; // inverse mod 2**32
        inv *= 2 - _denominator * inv; // inverse mod 2**64
        inv *= 2 - _denominator * inv; // inverse mod 2**128
        inv *= 2 - _denominator * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of _denominator. This will give us the
        // correct result modulo 2**256. Since the precoditions guarantee
        // that the outcome is less than 2**256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
        return result;
    }
}
