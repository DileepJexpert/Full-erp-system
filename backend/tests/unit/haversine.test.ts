import { describe, it, expect } from 'vitest';
import { haversineDistance, checkProximity } from '../../src/utils/haversine.js';

describe('haversineDistance', () => {
  it('should return 0 for same coordinates', () => {
    const distance = haversineDistance(28.6139, 77.2090, 28.6139, 77.2090);
    expect(distance).toBe(0);
  });

  it('should calculate distance between two points in Delhi (~1.5km)', () => {
    // Connaught Place to India Gate
    const distance = haversineDistance(28.6315, 77.2167, 28.6129, 77.2295);
    expect(distance).toBeGreaterThan(1400);
    expect(distance).toBeLessThan(2500);
  });

  it('should calculate short distances accurately', () => {
    // Two points ~100m apart
    const distance = haversineDistance(28.6139, 77.2090, 28.6148, 77.2090);
    expect(distance).toBeGreaterThan(90);
    expect(distance).toBeLessThan(110);
  });
});

describe('checkProximity', () => {
  it('should return withinRange=true for nearby coordinates', () => {
    const result = checkProximity(28.6139, 77.2090, 28.6140, 77.2091);
    expect(result.withinRange).toBe(true);
    expect(result.distance).toBeLessThan(200);
  });

  it('should return withinRange=false for distant coordinates', () => {
    const result = checkProximity(28.6139, 77.2090, 28.6200, 77.2200);
    expect(result.withinRange).toBe(false);
    expect(result.distance).toBeGreaterThan(200);
  });

  it('should flag as remote when > 100m but < 200m', () => {
    // Roughly 150m apart
    const result = checkProximity(28.6139, 77.2090, 28.6152, 77.2090);
    expect(result.isRemote).toBe(true);
    expect(result.withinRange).toBe(true);
  });

  it('should not flag as remote when very close', () => {
    const result = checkProximity(28.6139, 77.2090, 28.6139, 77.2091);
    expect(result.isRemote).toBe(false);
    expect(result.withinRange).toBe(true);
  });
});
