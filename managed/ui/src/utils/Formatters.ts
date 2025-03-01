import { isDefinedNotNull } from "./ObjectUtils";

/**
 * Format the duration into _d _h _m _s _ms format.
 */
export const formatDuration = (milliseconds: number) => {
  const isNegative = milliseconds < 0;
  const absoluteMilliseconds = Math.abs(milliseconds);

  const MILLISECONDS_IN_SECOND = 1000;
  const SECONDS_IN_MINUTE = 60;
  const MINUTES_IN_HOUR = 60;
  const HOURS_IN_DAY = 24;

  // d - day, h - hour, m - minutes, s - seconds, ms - milliseconds).
  // Units from greatest to least. Base unit should always be last in the array.
  const durationUnits = [
    {
      value: 0,
      unit: 'd',
      baseUnitFactor: MILLISECONDS_IN_SECOND * SECONDS_IN_MINUTE * MINUTES_IN_HOUR * HOURS_IN_DAY
    },
    {
      value: 0,
      unit: 'h',
      baseUnitFactor: MILLISECONDS_IN_SECOND * SECONDS_IN_MINUTE * MINUTES_IN_HOUR
    },
    {
      value: 0,
      unit: 'm',
      baseUnitFactor: MILLISECONDS_IN_SECOND * SECONDS_IN_MINUTE
    },
    {
      value: 0,
      unit: 's',
      baseUnitFactor: MILLISECONDS_IN_SECOND
    },
    {
      value: 0,
      unit: 'ms',
      baseUnitFactor: 1
    }
  ];

  if(!isDefinedNotNull(milliseconds)) return '-';

  if (milliseconds && !isFinite(milliseconds)) {
    return 0;
  }

  if (milliseconds === 0) {
    return `0${durationUnits[durationUnits.length - 1].unit}`;
  }

  let allocatedDuration = 0;
  durationUnits.forEach((durationUnit) => {
    durationUnit.value = Math.floor(
      (absoluteMilliseconds - allocatedDuration) / durationUnit.baseUnitFactor
    );
    allocatedDuration += durationUnit.value * durationUnit.baseUnitFactor;
  });

  return `${isNegative ? '-' : ''} ${durationUnits
    .map((durationUnit) =>
      durationUnit.value > 0 ? `${durationUnit.value}${durationUnit.unit}` : ''
    )
    .join(' ')}`;
};
