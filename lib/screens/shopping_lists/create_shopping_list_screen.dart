import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/product.dart';
import '../../services/shopping_list_service.dart';
import '../../services/smart_templates_service.dart';
import '../../services/smart_search_service.dart';
import '../../services/notification_service.dart';
import '../../providers/notification_provider.dart';

class CreateShoppingListScreen extends StatefulWidget {
  const CreateShoppingListScreen({Key? key}) : super(key: key);

  @override
  _CreateShoppingListScreenState createState() => _CreateShoppingListScreenState();
}

class _CreateShoppingListScreenState extends State<CreateShoppingListScreen> {
  final TextEditingController _listNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<ScoredProduct> _scoredResults = [];
  List<Product> _selectedProducts = [];
  bool _isSearching = false;
  bool _isCreating = false;
  bool _isAddingTemplate = false;
  Timer? _searchTimer;
  String? _detectedTemplate;
  SearchResultType? _lastSearchType;

  @override
  void initState() {
    super.initState();
    _listNameController.text = 'My Shopping List';
  }

  void _searchProducts(String query) async {
    _searchTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _scoredResults = [];
        _isSearching = false;
        _detectedTemplate = null;
        _lastSearchType = null;
      });
      return;
    }

    _searchTimer = Timer(Duration(milliseconds: 500), () async {
      setState(() {
        _isSearching = true;
      });

      try {
        final result = await SmartSearchService.smartSearch(query);

        setState(() {
          _lastSearchType = result.type;
        });

        switch (result.type) {
          case SearchResultType.autoAdd:
            if (result.bestProduct != null) {
              _addProduct(result.bestProduct!);
              _showSuccess('✅ Added "${result.bestProduct!.name}" (${result.confidence}% match)');
            }
            break;

          case SearchResultType.template:
            setState(() {
              _detectedTemplate = result.templateName;
              _isSearching = false;
            });
            break;

          case SearchResultType.suggestions:
            setState(() {
              _scoredResults = result.allMatches ?? [];
              _isSearching = false;
            });
            break;

          case SearchResultType.noResults:
            setState(() {
              _scoredResults = result.allMatches ?? [];
              _isSearching = false;
            });
            break;
        }

      } catch (e) {
        setState(() {
          _isSearching = false;
        });
        _showError('Failed to search products');
      }
    });
  }

  Future<void> _addTemplateProducts(String templateName) async {
    setState(() {
      _isAddingTemplate = true;
    });

    try {
      final templateProducts = await SmartTemplatesService.searchTemplateProducts(templateName);

      if (templateProducts.isEmpty) {
        _showError('No products found for $templateName template');
        return;
      }

      for (final product in templateProducts) {
        if (!_selectedProducts.any((p) => p.id == product.id)) {
          _selectedProducts.add(product);
        }
      }

      _searchController.clear();
      _scoredResults.clear();
      _detectedTemplate = null;

      _showSuccess('Added ${templateProducts.length} ${templateName} products to your list!');

    } catch (e) {
      _showError('Failed to add template products: $e');
    } finally {
      setState(() {
        _isAddingTemplate = false;
      });
    }
  }

  void _addProduct(Product product) {
    if (!_selectedProducts.any((p) => p.id == product.id)) {
      setState(() {
        _selectedProducts.add(product);
      });
      _searchController.clear();
      _scoredResults.clear();
      _detectedTemplate = null;
      _lastSearchType = null;
      FocusScope.of(context).unfocus();
    }
  }

  void _removeProduct(Product product) {
    setState(() {
      _selectedProducts.removeWhere((p) => p.id == product.id);
    });
    _showSuccess('${product.name} removed from list');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _createShoppingList() async {
    if (_listNameController.text.isEmpty) {
      _showError('Please enter a list name');
      return;
    }

    if (_selectedProducts.isEmpty) {
      _showError('Please add at least one product to the list');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final shoppingList = await ShoppingListService.createShoppingList(_listNameController.text);

      for (final product in _selectedProducts) {
        await ShoppingListService.addItemToList(shoppingList.id, product.id);
      }

      // Send notification for shopping list creation
      try {
        await NotificationService.notifyShoppingListCreated(
          _listNameController.text,
          _selectedProducts.length,
        );
        // Refresh notifications if provider is available
        if (context.mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          await notificationProvider.refresh();
        }
      } catch (e) {
        debugPrint('Error sending shopping list creation notification: $e');
      }

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Shopping list "${_listNameController.text}" created successfully!')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      _showError('Failed to create shopping list: $e');
    }
  }

  Widget _buildSearchStatus() {
    if (_isSearching) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Smart searching for "${_searchController.text}"...',
                style: TextStyle(color: Colors.blue.shade800),
              ),
            ),
          ],
        ),
      );
    }

    if (_lastSearchType == SearchResultType.autoAdd) {
      return SizedBox();
    }

    if (_lastSearchType == SearchResultType.noResults && _scoredResults.isEmpty) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 16),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 12),
            Text(
              'No products found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term or use a template below',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SizedBox();
  }

  Widget _buildTemplateSuggestion() {
    if (_detectedTemplate == null) return SizedBox();

    final templateName = _detectedTemplate!;
    final description = SmartTemplatesService.getTemplateDescription(templateName);
    final keywords = SmartTemplatesService.getTemplateKeywords(templateName).take(5).toList();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.purple.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome, color: Colors.blue.shade800, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Smart Template Detected!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '🎯 $description',
            style: TextStyle(color: Colors.blue.shade800, fontSize: 15),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: keywords.map((keyword) => Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                keyword,
                style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
              ),
            )).toList(),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isAddingTemplate ? null : () => _addTemplateProducts(templateName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isAddingTemplate
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_mosaic),
                      SizedBox(width: 8),
                      Text('Add $templateName products', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _detectedTemplate = null;
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Skip', style: TextStyle(color: Colors.grey.shade600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_scoredResults.isEmpty || _detectedTemplate != null) return SizedBox();

    final sortedResults = SmartSearchService.getSortedMatches(_scoredResults);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.blue.shade700, size: 20),
              SizedBox(width: 8),
              Text(
                'Search Results',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey.shade800),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sortedResults.length.toString(),
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                ),
              ),
              if (_lastSearchType == SearchResultType.suggestions)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Suggestions',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                  ),
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: sortedResults.map((scoredProduct) => _buildScoredProductItem(scoredProduct)).toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScoredProductItem(ScoredProduct scoredProduct) {
    final product = scoredProduct.product;
    final score = scoredProduct.score;

    Color scoreColor;
    if (score >= 80) {
      scoreColor = Colors.green;
    } else if (score >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _addProduct(product),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.green.shade50,
                    image: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: product.imageUrl == null || product.imageUrl!.isEmpty
                      ? Icon(Icons.shopping_bag, color: Colors.green.shade600, size: 24)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      if (product.price != null)
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      if (product.category != null)
                        Text(
                          product.category!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scoreColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.add, color: Colors.white, size: 18),
                        onPressed: () => _addProduct(product),
                        padding: EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableTemplates() {
    final templates = SmartTemplatesService.getAvailableTemplates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_mosaic, color: Colors.purple.shade600, size: 20),
              SizedBox(width: 8),
              Text(
                'Quick Templates',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: templates.map((template) => Container(
              margin: EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _searchController.text = template;
                    _searchProducts(template);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade50, Colors.blue.shade50],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.purple.shade600),
                        SizedBox(width: 6),
                        Text(
                          template,
                          style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSelectedProductItem(Product product) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.green.shade50,
            image: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? DecorationImage(
              image: NetworkImage(product.imageUrl!),
              fit: BoxFit.cover,
            )
                : null,
          ),
          child: product.imageUrl == null || product.imageUrl!.isEmpty
              ? Icon(Icons.shopping_bag, color: Colors.green.shade600, size: 20)
              : null,
        ),
        title: Text(
          product.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '\$${product.price?.toStringAsFixed(2) ?? '0.00'}',
          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(Icons.remove, color: Colors.red.shade600, size: 18),
            onPressed: () => _removeProduct(product),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Shopping List',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_selectedProducts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: _isCreating
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green.shade600),
                )
                    : Icon(Icons.save_alt_rounded, color: Colors.green.shade600),
                onPressed: _isCreating ? null : _createShoppingList,
              ),
            ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // Fixed top section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // List Name Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _listNameController,
                      decoration: InputDecoration(
                        labelText: 'List Name',
                        hintText: 'Enter list name...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.shopping_cart_rounded, color: Colors.green.shade600),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Quick Templates
                  _buildAvailableTemplates(),

                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search products or templates',
                        hintText: 'Type product name or "bakery", "breakfast"...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.blue.shade600),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: Colors.grey.shade500),
                          onPressed: () {
                            _searchController.clear();
                            _scoredResults.clear();
                            _detectedTemplate = null;
                            _lastSearchType = null;
                            setState(() {});
                          },
                        )
                            : null,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: _searchProducts,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Search Status
                  _buildSearchStatus(),

                  // Template Suggestion
                  _buildTemplateSuggestion(),
                ],
              ),
            ),

            // Scrollable middle and bottom section
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Results
                    _buildSearchResults(),

                    // Selected Products Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.shopping_basket_rounded, color: Colors.green.shade600, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Selected Products',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey.shade800),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _selectedProducts.length.toString(),
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _selectedProducts.isEmpty
                            ? Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300),
                              SizedBox(height: 16),
                              Text(
                                'Your list is empty',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Search for products or use templates to get started',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                            : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _selectedProducts.map((product) => _buildSelectedProductItem(product)).toList(),
                        ),
                        SizedBox(height: 16),

                        // Create Button
                        if (_selectedProducts.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 16),
                            child: ElevatedButton(
                              onPressed: _isCreating ? null : _createShoppingList,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                shadowColor: Colors.green.shade200,
                              ),
                              child: _isCreating
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_alt_rounded),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create Shopping List',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }
}