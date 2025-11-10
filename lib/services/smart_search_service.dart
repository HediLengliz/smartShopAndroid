import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import '../../models/product.dart';
import 'shopping_list_service.dart';
import 'smart_templates_service.dart';

class SmartSearchService {
  // Scoring thresholds
  static const int AUTO_ADD_THRESHOLD = 50;
  static const int SUGGEST_THRESHOLD = 30;
  static const int NO_RESULTS_THRESHOLD = 40;

  // Weights for different matching strategies
  static const int EXACT_MATCH_WEIGHT = 100;
  static const int STARTS_WITH_WEIGHT = 80;
  static const int CONTAINS_WEIGHT = 60;
  static const int FUZZY_MATCH_WEIGHT = 70;
  static const int CATEGORY_MATCH_WEIGHT = 90;

  static Future<SmartSearchResult> smartSearch(String query) async {
    final cleanQuery = query.trim().toLowerCase();

    // First check if it's a template
    final template = SmartTemplatesService.detectTemplateFromInput(cleanQuery);
    if (template != null) {
      return SmartSearchResult(
        type: SearchResultType.template,
        templateName: template,
        confidence: 95,
      );
    }

    // Search for products
    final products = await ShoppingListService.searchProducts(cleanQuery);

    if (products.isEmpty) {
      return SmartSearchResult(
        type: SearchResultType.noResults,
        confidence: 0,
      );
    }

    // Calculate scores for each product
    final scoredProducts = _calculateProductScores(products, cleanQuery);

    // Find best match
    final bestMatch = _findBestMatch(scoredProducts);

    // Determine result type based on best match score
    if (bestMatch.score >= AUTO_ADD_THRESHOLD) {
      return SmartSearchResult(
        type: SearchResultType.autoAdd,
        bestProduct: bestMatch.product,
        confidence: bestMatch.score,
        allMatches: scoredProducts,
      );
    } else if (bestMatch.score >= SUGGEST_THRESHOLD) {
      return SmartSearchResult(
        type: SearchResultType.suggestions,
        bestProduct: bestMatch.product,
        confidence: bestMatch.score,
        allMatches: scoredProducts,
      );
    } else {
      return SmartSearchResult(
        type: SearchResultType.noResults,
        confidence: bestMatch.score,
        allMatches: scoredProducts,
      );
    }
  }

  static List<ScoredProduct> _calculateProductScores(List<Product> products, String query) {
    return products.map((product) {
      int score = 0;

      // Exact name match
      if (product.name.toLowerCase() == query) {
        score = EXACT_MATCH_WEIGHT;
      }
      // Starts with match
      else if (product.name.toLowerCase().startsWith(query)) {
        score = STARTS_WITH_WEIGHT;
      }
      // Contains match
      else if (product.name.toLowerCase().contains(query)) {
        score = CONTAINS_WEIGHT;
      }
      // Fuzzy matching
      else {
        final fuzzyScore = ratio(query, product.name.toLowerCase());
        score = (fuzzyScore * FUZZY_MATCH_WEIGHT / 100).round();
      }

      // Category bonus
      if (product.category != null) {
        final categoryScore = ratio(query, product.category!.toLowerCase());
        if (categoryScore > 50) {
          score += (categoryScore * CATEGORY_MATCH_WEIGHT / 100).round();
        }
      }

      // Description bonus (if available)
      if (product.description != null) {
        final descScore = ratio(query, product.description!.toLowerCase());
        if (descScore > 60) {
          score += (descScore * 20 / 100).round(); // Smaller weight for description
        }
      }

      // Cap score at 100
      score = score.clamp(0, 100);

      return ScoredProduct(product: product, score: score);
    }).toList();
  }

  static ScoredProduct _findBestMatch(List<ScoredProduct> scoredProducts) {
    scoredProducts.sort((a, b) => b.score.compareTo(a.score));
    return scoredProducts.first;
  }

  // Get products sorted by score
  static List<ScoredProduct> getSortedMatches(List<ScoredProduct> scoredProducts) {
    return scoredProducts..sort((a, b) => b.score.compareTo(a.score));
  }

  // Check if we should show "no results" based on best match score
  static bool shouldShowNoResults(List<ScoredProduct> scoredProducts) {
    if (scoredProducts.isEmpty) return true;
    final bestScore = _findBestMatch(scoredProducts).score;
    return bestScore < NO_RESULTS_THRESHOLD;
  }
}

class ScoredProduct {
  final Product product;
  final int score;

  ScoredProduct({required this.product, required this.score});
}

class SmartSearchResult {
  final SearchResultType type;
  final Product? bestProduct;
  final String? templateName;
  final int confidence;
  final List<ScoredProduct>? allMatches;

  SmartSearchResult({
    required this.type,
    this.bestProduct,
    this.templateName,
    required this.confidence,
    this.allMatches,
  });
}

enum SearchResultType {
  autoAdd,      // Score >= 50: Add automatically
  suggestions,  // Score 30-49: Show suggestions
  template,     // Template detected
  noResults,    // Score < 30: No good matches
}