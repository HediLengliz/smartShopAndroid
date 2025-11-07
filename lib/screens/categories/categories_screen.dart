import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'category_products_screen.dart';
import '../home/widgets/home_template.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<String> categories = [];
  bool isLoading = true;
  String? error;

  // Map des catégories vers les images HD
  final Map<String, String> categoryImages = {
    'Bakery':     'https://www.conect.org.tn/wp-content/uploads/2022/03/lIndustrie-de-la-Boulangerie-et-de-la-Patisserie.jpg',
    'Beverages':  'https://cdn.prod.website-files.com/5f97839dbb364182a84ef584/612900407bd12963b422a20d_Q321_Evergi_Trending-Ingredients-Functional-Bev_Feature-Image.jpg',
    'Dairy':      'https://www.bruker.com/en/applications/food-analysis-and-agriculture/food-quality/milk-and-dairy/_jcr_content/root/herostage/backgroundImageVPL.coreimg.82.1920.jpeg/1596451146895/milk-dairy.jpeg',
    'Fruits':     'https://www.gastronomiac.com/wp/wp-content/uploads/2021/08/Fruits.jpg',
    'Meat':       'https://www.freshfarms.com/wp-content/uploads/2023/02/A-Guide-to-Choosing-the-Right-Type-of-Meat-for-Your-Meal.jpg',
    'Pantry':     'https://images.unsplash.com/photo-1585238342020-5ecf29dc2b08?auto=format&fit=crop&w=800&q=80',
    'Vegetables': 'https://upload.wikimedia.org/wikipedia/commons/2/24/Marketvegetables.jpg',
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();

    // Précharge les images après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadCategoryImages();
    });
  }

  Future<void> _loadCategories() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final fetched = await ApiService.fetchCategories();
      // On ne garde que les catégories pour lesquelles on a une image
      final filtered = fetched.where((c) => categoryImages.containsKey(c)).toList();
      setState(() => categories = filtered);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _preloadCategoryImages() {
    categoryImages.values.forEach((url) {
      precacheImage(NetworkImage(url), context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HomeTemplate(
      currentIndex: 1,
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text('Error: $error'))
          : categories.isEmpty
          ? const Center(child: Text('No categories found'))
          : GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final imageUrl = categoryImages[category]!;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryProductsScreen(category: category),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
