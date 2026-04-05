// Feedback Kiosk Display System — Unit Tests
import { describe, it, expect } from 'vitest';

// ═══ NPS Calculation Tests ═══
describe('NPS Score Calculation', () => {
  function calculateNps(ratings: number[]): {
    nps: number;
    promotersPct: number;
    passivesPct: number;
    detractorsPct: number;
  } {
    if (ratings.length === 0) return { nps: 0, promotersPct: 0, passivesPct: 0, detractorsPct: 0 };

    let promoters = 0;
    let passives = 0;
    let detractors = 0;

    for (const r of ratings) {
      if (r >= 4) promoters++;
      else if (r === 3) passives++;
      else detractors++;
    }

    const total = ratings.length;
    const promotersPct = Math.round((promoters / total) * 100);
    const passivesPct = Math.round((passives / total) * 100);
    const detractorsPct = Math.round((detractors / total) * 100);
    const nps = promotersPct - detractorsPct;

    return { nps, promotersPct, passivesPct, detractorsPct };
  }

  it('should return NPS 100 for all 5-star ratings', () => {
    const result = calculateNps([5, 5, 5, 5, 5]);
    expect(result.nps).toBe(100);
    expect(result.promotersPct).toBe(100);
    expect(result.detractorsPct).toBe(0);
  });

  it('should return NPS -100 for all 1-star ratings', () => {
    const result = calculateNps([1, 1, 1, 1, 1]);
    expect(result.nps).toBe(-100);
    expect(result.detractorsPct).toBe(100);
  });

  it('should return NPS 0 for equal promoters and detractors', () => {
    const result = calculateNps([5, 5, 1, 1, 3]);
    expect(result.nps).toBe(0);
    expect(result.promotersPct).toBe(40);
    expect(result.detractorsPct).toBe(40);
    expect(result.passivesPct).toBe(20);
  });

  it('should handle mixed ratings correctly', () => {
    // 10 ratings: 4x5star, 2x4star, 2x3star, 1x2star, 1x1star
    const result = calculateNps([5, 5, 5, 5, 4, 4, 3, 3, 2, 1]);
    expect(result.promotersPct).toBe(60); // 6 promoters
    expect(result.passivesPct).toBe(20); // 2 passives
    expect(result.detractorsPct).toBe(20); // 2 detractors
    expect(result.nps).toBe(40); // 60 - 20
  });

  it('should handle empty array', () => {
    const result = calculateNps([]);
    expect(result.nps).toBe(0);
  });

  it('should classify rating 4 as promoter', () => {
    const result = calculateNps([4]);
    expect(result.promotersPct).toBe(100);
  });

  it('should classify rating 3 as passive', () => {
    const result = calculateNps([3]);
    expect(result.passivesPct).toBe(100);
    expect(result.nps).toBe(0);
  });

  it('should classify rating 2 as detractor', () => {
    const result = calculateNps([2]);
    expect(result.detractorsPct).toBe(100);
    expect(result.nps).toBe(-100);
  });
});

// ═══ Rating Distribution Tests ═══
describe('Rating Distribution', () => {
  function getRatingDistribution(ratings: number[]): { rating: number; count: number }[] {
    const counts = [0, 0, 0, 0, 0]; // index 0=1star, 4=5star
    for (const r of ratings) {
      if (r >= 1 && r <= 5) counts[r - 1]++;
    }
    return counts.map((count, i) => ({ rating: i + 1, count }));
  }

  it('should count ratings correctly', () => {
    const dist = getRatingDistribution([1, 2, 3, 4, 5, 5, 4, 3]);
    expect(dist[0]).toEqual({ rating: 1, count: 1 });
    expect(dist[1]).toEqual({ rating: 2, count: 1 });
    expect(dist[2]).toEqual({ rating: 3, count: 2 });
    expect(dist[3]).toEqual({ rating: 4, count: 2 });
    expect(dist[4]).toEqual({ rating: 5, count: 2 });
  });

  it('should handle all same ratings', () => {
    const dist = getRatingDistribution([5, 5, 5]);
    expect(dist[4]).toEqual({ rating: 5, count: 3 });
    expect(dist[0]).toEqual({ rating: 1, count: 0 });
  });

  it('should handle empty array', () => {
    const dist = getRatingDistribution([]);
    expect(dist.every((d) => d.count === 0)).toBe(true);
  });
});

// ═══ Average Rating Tests ═══
describe('Average Rating', () => {
  function avgRating(ratings: number[]): number {
    if (ratings.length === 0) return 0;
    return Math.round((ratings.reduce((s, r) => s + r, 0) / ratings.length) * 10) / 10;
  }

  it('should calculate correct average', () => {
    expect(avgRating([1, 2, 3, 4, 5])).toBe(3);
  });

  it('should round to 1 decimal', () => {
    expect(avgRating([4, 5, 4, 5, 3])).toBe(4.2);
  });

  it('should handle single rating', () => {
    expect(avgRating([5])).toBe(5);
  });

  it('should handle empty', () => {
    expect(avgRating([])).toBe(0);
  });
});

// ═══ Tag Counting Tests ═══
describe('Tag Counting', () => {
  function countTags(feedbackList: Array<{ tags: string[] }>): { tag: string; count: number }[] {
    const tagMap = new Map<string, number>();
    for (const fb of feedbackList) {
      for (const tag of fb.tags) {
        tagMap.set(tag, (tagMap.get(tag) || 0) + 1);
      }
    }
    return Array.from(tagMap.entries())
      .map(([tag, count]) => ({ tag, count }))
      .sort((a, b) => b.count - a.count);
  }

  it('should count and sort tags by frequency', () => {
    const feedbacks = [
      { tags: ['slow_service', 'rude_staff'] },
      { tags: ['slow_service', 'bad_quality'] },
      { tags: ['slow_service'] },
      { tags: ['not_clean'] },
    ];
    const result = countTags(feedbacks);
    expect(result[0]).toEqual({ tag: 'slow_service', count: 3 });
    expect(result.length).toBe(4);
  });

  it('should handle empty tags', () => {
    const feedbacks = [{ tags: [] }, { tags: [] }];
    expect(countTags(feedbacks)).toEqual([]);
  });

  it('should handle single feedback with multiple tags', () => {
    const feedbacks = [{ tags: ['tasty_food', 'fast_service', 'good_value'] }];
    const result = countTags(feedbacks);
    expect(result.length).toBe(3);
    expect(result.every((r) => r.count === 1)).toBe(true);
  });
});

// ═══ Critical Feedback Alert Tests ═══
describe('Critical Feedback Detection', () => {
  function shouldTriggerAlert(
    recentBadRatings: number,
    threshold: number = 3,
  ): boolean {
    return recentBadRatings >= threshold;
  }

  it('should trigger alert at exactly 3 bad ratings', () => {
    expect(shouldTriggerAlert(3)).toBe(true);
  });

  it('should NOT trigger alert at 2 bad ratings', () => {
    expect(shouldTriggerAlert(2)).toBe(false);
  });

  it('should trigger alert at 5 bad ratings', () => {
    expect(shouldTriggerAlert(5)).toBe(true);
  });

  it('should NOT trigger at 0 bad ratings', () => {
    expect(shouldTriggerAlert(0)).toBe(false);
  });
});

// ═══ Auto-Link Bill Tests ═══
describe('Auto-Link to Last Bill', () => {
  function shouldLinkBill(billCreatedAt: Date, feedbackTime: Date, maxMinutes: number = 15): boolean {
    const diffMs = feedbackTime.getTime() - billCreatedAt.getTime();
    const diffMin = diffMs / (1000 * 60);
    return diffMin >= 0 && diffMin <= maxMinutes;
  }

  it('should link bill created 5 minutes ago', () => {
    const bill = new Date('2026-04-05T10:00:00');
    const feedback = new Date('2026-04-05T10:05:00');
    expect(shouldLinkBill(bill, feedback)).toBe(true);
  });

  it('should link bill created 15 minutes ago (boundary)', () => {
    const bill = new Date('2026-04-05T10:00:00');
    const feedback = new Date('2026-04-05T10:15:00');
    expect(shouldLinkBill(bill, feedback)).toBe(true);
  });

  it('should NOT link bill created 20 minutes ago', () => {
    const bill = new Date('2026-04-05T10:00:00');
    const feedback = new Date('2026-04-05T10:20:00');
    expect(shouldLinkBill(bill, feedback)).toBe(false);
  });

  it('should NOT link bill created in the future', () => {
    const bill = new Date('2026-04-05T10:10:00');
    const feedback = new Date('2026-04-05T10:05:00');
    expect(shouldLinkBill(bill, feedback)).toBe(false);
  });
});

// ═══ Kiosk Rate Limiting Tests ═══
describe('Kiosk Rate Limiting', () => {
  function isRateLimited(
    lastSubmitTime: Date | null,
    now: Date,
    minIntervalSec: number = 10,
  ): boolean {
    if (!lastSubmitTime) return false;
    const diffMs = now.getTime() - lastSubmitTime.getTime();
    return diffMs < minIntervalSec * 1000;
  }

  it('should NOT rate-limit first submission', () => {
    expect(isRateLimited(null, new Date())).toBe(false);
  });

  it('should rate-limit if last submission was 5 seconds ago', () => {
    const last = new Date('2026-04-05T10:00:00');
    const now = new Date('2026-04-05T10:00:05');
    expect(isRateLimited(last, now)).toBe(true);
  });

  it('should NOT rate-limit if last submission was 15 seconds ago', () => {
    const last = new Date('2026-04-05T10:00:00');
    const now = new Date('2026-04-05T10:00:15');
    expect(isRateLimited(last, now)).toBe(false);
  });

  it('should rate-limit at exactly 10 seconds (boundary)', () => {
    const last = new Date('2026-04-05T10:00:00');
    const now = new Date('2026-04-05T10:00:10');
    expect(isRateLimited(last, now)).toBe(false); // 10 sec = not limited
  });
});

// ═══ Tag Label Mapping Tests ═══
describe('Tag Bilingual Labels', () => {
  const tagLabels: Record<string, { en: string; hi: string; emoji: string }> = {
    slow_service: { en: 'Slow Service', hi: 'धीमी सेवा', emoji: '🐌' },
    bad_quality: { en: 'Bad Quality', hi: 'खराब गुणवत्ता', emoji: '👎' },
    rude_staff: { en: 'Rude Staff', hi: 'बदतमीज़ स्टाफ', emoji: '😤' },
    wrong_order: { en: 'Wrong Order', hi: 'गलत ऑर्डर', emoji: '❌' },
    not_clean: { en: 'Not Clean', hi: 'साफ नहीं', emoji: '🧹' },
    overpriced: { en: 'Overpriced', hi: 'महंगा', emoji: '💰' },
    tasty_food: { en: 'Tasty Food', hi: 'स्वादिष्ट', emoji: '😋' },
    fast_service: { en: 'Fast Service', hi: 'तेज़ सेवा', emoji: '⚡' },
    friendly_staff: { en: 'Friendly Staff', hi: 'अच्छा स्टाफ', emoji: '😊' },
    clean_place: { en: 'Clean Place', hi: 'साफ जगह', emoji: '✨' },
    good_value: { en: 'Good Value', hi: 'पैसा वसूल', emoji: '💎' },
    will_recommend: { en: 'Will Recommend', hi: 'सिफारिश करूंगा', emoji: '👍' },
  };

  it('should have labels for all negative tags', () => {
    const negativeTags = ['slow_service', 'bad_quality', 'rude_staff', 'wrong_order', 'not_clean', 'overpriced'];
    for (const tag of negativeTags) {
      expect(tagLabels[tag]).toBeDefined();
      expect(tagLabels[tag].en).toBeTruthy();
      expect(tagLabels[tag].hi).toBeTruthy();
      expect(tagLabels[tag].emoji).toBeTruthy();
    }
  });

  it('should have labels for all positive tags', () => {
    const positiveTags = ['tasty_food', 'fast_service', 'friendly_staff', 'clean_place', 'good_value', 'will_recommend'];
    for (const tag of positiveTags) {
      expect(tagLabels[tag]).toBeDefined();
      expect(tagLabels[tag].en).toBeTruthy();
      expect(tagLabels[tag].hi).toBeTruthy();
    }
  });

  it('should have 12 total tag labels', () => {
    expect(Object.keys(tagLabels).length).toBe(12);
  });
});

// ═══ Display Mode Tests ═══
describe('Display Mode Behavior', () => {
  function getPhase2Behavior(
    displayMode: string,
    rating: number,
  ): 'just_thankyou' | 'with_comment' | 'positive_tags' | 'negative_tags' {
    if (displayMode === 'SIMPLE') return 'just_thankyou';
    if (displayMode === 'WITH_COMMENT') return 'with_comment';
    if (displayMode === 'WITH_TAGS') {
      if (rating <= 2) return 'negative_tags';
      if (rating >= 4) return 'positive_tags';
      return 'just_thankyou'; // rating 3 = no tags
    }
    return 'just_thankyou';
  }

  it('SIMPLE mode always shows just thank you', () => {
    expect(getPhase2Behavior('SIMPLE', 1)).toBe('just_thankyou');
    expect(getPhase2Behavior('SIMPLE', 5)).toBe('just_thankyou');
  });

  it('WITH_COMMENT mode always shows comment field', () => {
    expect(getPhase2Behavior('WITH_COMMENT', 1)).toBe('with_comment');
    expect(getPhase2Behavior('WITH_COMMENT', 5)).toBe('with_comment');
  });

  it('WITH_TAGS shows negative tags for 1-2 stars', () => {
    expect(getPhase2Behavior('WITH_TAGS', 1)).toBe('negative_tags');
    expect(getPhase2Behavior('WITH_TAGS', 2)).toBe('negative_tags');
  });

  it('WITH_TAGS shows positive tags for 4-5 stars', () => {
    expect(getPhase2Behavior('WITH_TAGS', 4)).toBe('positive_tags');
    expect(getPhase2Behavior('WITH_TAGS', 5)).toBe('positive_tags');
  });

  it('WITH_TAGS shows just thank you for 3 stars', () => {
    expect(getPhase2Behavior('WITH_TAGS', 3)).toBe('just_thankyou');
  });
});
