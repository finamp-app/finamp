import 'package:finamp/services/user_rating_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ratingToStars', () {
    test('maps Jellyfin 0-10 ratings to five stars', () {
      expect(ratingToStars(null), 0);
      expect(ratingToStars(0), 0);
      expect(ratingToStars(2), 1);
      expect(ratingToStars(4), 2);
      expect(ratingToStars(6), 3);
      expect(ratingToStars(8), 4);
      expect(ratingToStars(10), 5);
    });

    test('rounds intermediate Jellyfin ratings to the nearest star', () {
      expect(ratingToStars(1), 1);
      expect(ratingToStars(3), 2);
      expect(ratingToStars(5), 3);
      expect(ratingToStars(7), 4);
      expect(ratingToStars(9), 5);
    });

    test('clamps out-of-range input defensively', () {
      expect(ratingToStars(-1), 0);
      expect(ratingToStars(11), 5);
    });
  });

  group('ratingToStarValue', () {
    test('preserves half-star values from Jellyfin', () {
      expect(ratingToStarValue(1), 0.5);
      expect(ratingToStarValue(3), 1.5);
      expect(ratingToStarValue(5), 2.5);
      expect(ratingToStarValue(7), 3.5);
      expect(ratingToStarValue(9), 4.5);
    });

    test('clamps out-of-range values', () {
      expect(ratingToStarValue(-1), 0.0);
      expect(ratingToStarValue(11), 5.0);
    });
  });

  group('starsToRating', () {
    test('maps five stars to Jellyfin 0-10 rating values', () {
      expect(starsToRating(1), 2.0);
      expect(starsToRating(2), 4.0);
      expect(starsToRating(3), 6.0);
      expect(starsToRating(4), 8.0);
      expect(starsToRating(5), 10.0);
    });

    test('maps half stars to odd Jellyfin rating values', () {
      expect(starsToRating(0.5), 1.0);
      expect(starsToRating(1.5), 3.0);
      expect(starsToRating(2.5), 5.0);
      expect(starsToRating(3.5), 7.0);
      expect(starsToRating(4.5), 9.0);
    });

    test('clamps invalid star counts defensively', () {
      expect(starsToRating(0), 1.0);
      expect(starsToRating(6), 10.0);
    });
  });
}
