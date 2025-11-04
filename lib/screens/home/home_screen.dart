import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/search_bar.dart';
import 'widgets/category_bar.dart';
import 'widgets/product_grid.dart';
import 'widgets/home_template.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> products = [];
  bool isLoading = true;
  String? error;
  String? searchQuery;

  List<String> categories = [];
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts({String? category, String? search}) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final fetchedProducts =
      await ApiService.fetchProducts(search: search ?? searchQuery, category: category);

      setState(() {
        products = fetchedProducts;
        categories = fetchedProducts.map((p) => p.category ?? "Other").toSet().toList();
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void onSearch(String value) {
    searchQuery = value;
    fetchProducts(search: value, category: selectedCategory);
  }

  void selectCategory(String category) {
    setState(() {
      selectedCategory = (selectedCategory == category) ? null : category;
    });
    fetchProducts(search: searchQuery, category: selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return HomeTemplate(
      currentIndex: 0,
      appBar: const HomeAppBar(),
      body: Column(
        children: [
          HomeSearchBar(onChanged: onSearch),
          CategoryBar(
            categories: categories,
            selectedCategory: selectedCategory,
            onSelect: selectCategory,
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text('Error: $error'))
                : products.isEmpty
                ? const Center(child: Text('No products found'))
                : ProductGrid(products: products),
          ),
        ],
      ),
    );
  }}