/**
 * Oregon Rent Stabilization Cap Calculator
 * Ported from the Twin Oaks concept system (_archive/TwinOaks/src/utils/rentCap.ts).
 *
 * ORS 90.600 / HB 3054 (2025)
 * - Parks with >30 spaces: 6% max annual increase
 * - Parks with ≤30 spaces: 7% + CPI (West Region), capped at 10%
 * - Major infrastructure updates (>30 spaces): up to 12%
 * - Buyer of home sited in park: 10% above seller's rent
 */

/** Published caps by year. Update annually from OEA by October 1. */
const RENT_CAPS: Record<number, { large: number; small: number }> = {
  2026: { large: 0.06, small: 0.095 },
  2025: { large: 0.1, small: 0.1 },
};

/** Twin Oaks has 61 spaces (>30), so the large-park cap applies. */
const TWIN_OAKS_SPACE_COUNT = 61;

export function getRentCap(year: number): number {
  const caps = RENT_CAPS[year];
  if (!caps) return RENT_CAPS[2026]!.large; // fallback to most recent known
  return TWIN_OAKS_SPACE_COUNT > 30 ? caps.large : caps.small;
}

export function calculateMaxRent(currentRent: number, year: number): number {
  const cap = getRentCap(year);
  return Math.round(currentRent * (1 + cap) * 100) / 100;
}

export interface RentIncreaseCheck {
  valid: boolean;
  maxAllowed: number;
  percentIncrease: number;
  cap: number;
}

export function validateRentIncrease(
  currentRent: number,
  proposedRent: number,
  year: number,
): RentIncreaseCheck {
  const cap = getRentCap(year);
  const maxAllowed = calculateMaxRent(currentRent, year);
  const percentIncrease = currentRent === 0 ? 0 : (proposedRent - currentRent) / currentRent;
  return { valid: proposedRent <= maxAllowed, maxAllowed, percentIncrease, cap };
}
