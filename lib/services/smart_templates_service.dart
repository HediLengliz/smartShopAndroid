import '../../models/product.dart';
import 'shopping_list_service.dart';

class SmartTemplatesService {
  // Define smart templates with category keywords and suggested products
  static final Map<String, List<String>> _smartTemplates = {
    'bakery': [
      'bread', 'croissant', 'baguette', 'bagel', 'muffin',
      'cake', 'pastry', 'donut', 'cookie', 'bun'
    ],
    'breakfast': [
      'milk', 'cereal', 'eggs', 'yogurt', 'oatmeal',
      'pancake', 'waffle', 'juice', 'coffee', 'tea'
    ],
    'fruits': [
      'apple', 'banana', 'orange', 'grape', 'strawberry',
      'blueberry', 'mango', 'pineapple', 'watermelon', 'peach'
    ],
    'vegetables': [
      'carrot', 'tomato', 'potato', 'onion', 'lettuce',
      'broccoli', 'spinach', 'cucumber', 'pepper', 'garlic'
    ],
    'dairy': [
      'milk', 'cheese', 'yogurt', 'butter', 'cream',
      'sour cream', 'cottage cheese', 'whipping cream'
    ],
    'meat': [
      'chicken', 'beef', 'pork', 'fish', 'salmon',
      'turkey', 'bacon', 'sausage', 'steak'
    ],
    'cleaning': [
      'detergent', 'soap', 'sponge', 'cleaner', 'bleach',
      'disinfectant', 'paper towel', 'trash bag'
    ],
    'beverages': [
      'water', 'soda', 'juice', 'coffee', 'tea',
      'beer', 'wine', 'energy drink', 'sports drink'
    ],
    'snacks': [
      'chips', 'cookies', 'crackers', 'nuts', 'popcorn',
      'chocolate', 'candy', 'granola bar', 'trail mix'
    ],
    'pantry': [
      'pasta', 'rice', 'flour', 'sugar', 'oil',
      'salt', 'pepper', 'spices', 'canned goods'
    ],
  };

  // Get available template names
  static List<String> getAvailableTemplates() {
    return _smartTemplates.keys.toList();
  }

  // Check if input matches any template
  static bool isTemplateInput(String input) {
    final cleanInput = input.trim().toLowerCase();
    return _smartTemplates.containsKey(cleanInput);
  }

  // Get template keywords for a given input
  static List<String> getTemplateKeywords(String templateName) {
    return _smartTemplates[templateName.toLowerCase()] ?? [];
  }

  // Search for products based on template keywords
  static Future<List<Product>> searchTemplateProducts(String templateName) async {
    final keywords = getTemplateKeywords(templateName);
    final allProducts = <Product>[];

    // Search for each keyword and collect products
    for (final keyword in keywords) {
      try {
        final products = await ShoppingListService.searchProducts(keyword);
        allProducts.addAll(products);
      } catch (e) {
        print('❌ Error searching for $keyword: $e');
        // Continue with other keywords even if one fails
      }
    }

    // Remove duplicates (same product ID)
    final uniqueProducts = <Product>[];
    final seenIds = <int>{};

    for (final product in allProducts) {
      if (!seenIds.contains(product.id)) {
        uniqueProducts.add(product);
        seenIds.add(product.id);
      }
    }

    print('🔍 Template "$templateName" found ${uniqueProducts.length} unique products');
    return uniqueProducts;
  }

  // Auto-detect template from user input
  static String? detectTemplateFromInput(String input) {
    final cleanInput = input.trim().toLowerCase();

    // Direct match
    if (_smartTemplates.containsKey(cleanInput)) {
      return cleanInput;
    }

    // Partial match or synonym
    for (final template in _smartTemplates.keys) {
      if (cleanInput.contains(template) || _isSynonym(cleanInput, template)) {
        return template;
      }
    }

    return null;
  }

  // Helper method for synonyms
  static bool _isSynonym(String input, String template) {
    final synonyms = {
      'bakery': ['baked', 'bread', 'pastry'],
      'breakfast': ['morning', 'cereal', 'eggs'],
      'fruits': ['fruit', 'apple', 'banana'],
      'vegetables': ['vegetable', 'veggie', 'salad'],
      'dairy': ['milk', 'cheese', 'yogurt'],
      'meat': ['chicken', 'beef', 'protein'],
      'cleaning': ['clean', 'household', 'supplies'],
      'beverages': ['drinks', 'beverage', 'liquid'],
      'snacks': ['snack', 'munchies', 'treats'],
      'pantry': ['staple', 'basic', 'essential'],
    };

    final templateSynonyms = synonyms[template] ?? [];
    return templateSynonyms.any((synonym) => input.contains(synonym));
  }

  // Get template description
  static String getTemplateDescription(String templateName) {
    final descriptions = {
      'bakery': 'Fresh bread, pastries, and baked goods',
      'breakfast': 'Everything you need for a perfect morning',
      'fruits': 'Fresh and delicious fruits',
      'vegetables': 'Healthy vegetables for your meals',
      'dairy': 'Milk, cheese, yogurt and dairy products',
      'meat': 'Fresh meat, poultry, and fish',
      'cleaning': 'Household cleaning supplies',
      'beverages': 'Drinks and beverages for any occasion',
      'snacks': 'Tasty snacks and treats',
      'pantry': 'Essential pantry staples and basics',
    };

    return descriptions[templateName] ?? 'Smart product selection';
  }
}