import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/product.dart';
import '../../services/shopping_list_service.dart';
import '../../services/smart_search_service.dart';
import '../../services/smart_templates_service.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  final ShoppingList shoppingList;

  const ShoppingListDetailScreen({Key? key, required this.shoppingList}) : super(key: key);

  @override
  _ShoppingListDetailScreenState createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  List<ShoppingListItem> _items = [];
  bool _isLoading = true;
  bool _showSearch = false;
  bool _showStats = false;
  final TextEditingController _searchController = TextEditingController();
  List<ScoredProduct> _scoredResults = [];
  bool _isSearching = false;
  bool _isAddingTemplate = false;
  Timer? _searchTimer;
  String? _detectedTemplate;
  SearchResultType? _lastSearchType;

  @override
  void initState() {
    super.initState();
    _loadListDetails();
  }

  Future<void> _loadListDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final result = await ShoppingListService.getShoppingList(widget.shoppingList.id);
      setState(() {
        _items = result['items'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load list details');
    }
  }

  ListStatistics get _listStatistics {
    return ListStatistics.calculateFromItems(_items);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _scoredResults.clear();
        _detectedTemplate = null;
        _lastSearchType = null;
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _toggleStats() {
    setState(() {
      _showStats = !_showStats;
    });
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
        await _addProduct(product);
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

  Future<void> _addProduct(Product product) async {
    try {
      final existingItem = _items.firstWhere(
            (item) => item.productId == product.id,
        orElse: () => ShoppingListItem(
          id: 0,
          listId: 0,
          productId: 0,
          productName: '',
          quantity: 0,
          isPurchased: false,
          position: 0,
          createdAt: DateTime.now(),
        ),
      );

      if (existingItem.id != 0) {
        await _updateItemQuantity(existingItem, existingItem.quantity + 1);
        _showSuccess('${product.name} quantity increased');
      } else {
        await ShoppingListService.addItemToList(widget.shoppingList.id, product.id);
        _showSuccess('${product.name} added to list');
        await _loadListDetails();
      }

      _searchController.clear();
      _scoredResults.clear();
      _detectedTemplate = null;
      setState(() {
        _showSearch = false;
      });
    } catch (e) {
      _showError('Failed to add product to list');
    }
  }

  Future<void> _toggleItemPurchased(ShoppingListItem item) async {
    try {
      final updatedItem = await ShoppingListService.updateListItem(
        item.listId,
        item.id,
        isPurchased: !item.isPurchased,
      );

      setState(() {
        final index = _items.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _items[index] = updatedItem;
        }
      });
    } catch (e) {
      _showError('Failed to update item');
    }
  }

  Future<void> _updateItemQuantity(ShoppingListItem item, int newQuantity) async {
    if (newQuantity <= 0) {
      _removeItem(item);
      return;
    }

    try {
      final updatedItem = await ShoppingListService.updateListItem(
        item.listId,
        item.id,
        quantity: newQuantity,
      );

      setState(() {
        final index = _items.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _items[index] = updatedItem;
        }
      });
    } catch (e) {
      _showError('Failed to update quantity');
    }
  }

  Future<void> _removeItem(ShoppingListItem item) async {
    try {
      await ShoppingListService.removeItemFromList(item.listId, item.id);
      setState(() {
        _items.removeWhere((i) => i.id == item.id);
      });
      _showSuccess('Item removed from list');
    } catch (e) {
      _showError('Failed to remove item');
    }
  }

  // Enhanced Statistics Card with Modern Design
  Widget _buildStatisticsCard() {
    final stats = _listStatistics;
    final completedPercentage = stats.totalItems > 0 ? (stats.completedItems / stats.totalItems) : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with improved design
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics, color: Colors.blue.shade700, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'List Analytics',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.blue.shade900,
                  ),
                ),
                Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(_showStats ? Icons.expand_less : Icons.expand_more),
                    onPressed: _toggleStats,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Progress indicator with percentage
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '${(completedPercentage * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.purple.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: completedPercentage,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade500,
                                  Colors.purple.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${stats.completedItems}/${stats.totalItems} items',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_showStats) ...[
              SizedBox(height: 20),

              // Financial Statistics Grid
              _buildStatSection(
                '💰 Financial Overview',
                Icons.attach_money,
                Colors.green,
                [
                  _buildModernStatItem(
                    'Estimated Total',
                    '\$${stats.estimatedTotalCost}',
                    Colors.green.shade700,
                    Icons.shopping_cart,
                  ),
                  _buildModernStatItem(
                    'Spent So Far',
                    '\$${stats.purchasedCost}',
                    Colors.blue.shade700,
                    Icons.payment,
                  ),
                  _buildModernStatItem(
                    'Remaining Cost',
                    '\$${stats.remainingCost}',
                    Colors.orange.shade700,
                    Icons.schedule,
                  ),
                  _buildModernStatItem(
                    'Avg. Item Price',
                    '\$${stats.averageItemPrice}',
                    Colors.purple.shade700,
                    Icons.analytics,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Progress Insights Grid
              _buildStatSection(
                '📊 Progress Insights',
                Icons.insights,
                Colors.purple,
                [
                  _buildModernStatItem(
                    'Completion Rate',
                    '${(stats.completionRate * 100).round()}%',
                    Colors.purple.shade700,
                    Icons.trending_up,
                  ),
                  _buildModernStatItem(
                    'Items Completed',
                    '${stats.completedItems}/${stats.totalItems}',
                    Colors.blue.shade700,
                    Icons.check_circle,
                  ),
                  _buildModernStatItem(
                    'Unique Categories',
                    '${stats.uniqueCategories}',
                    Colors.teal.shade700,
                    Icons.category,
                  ),
                  _buildModernStatItem(
                    'Cost per Item',
                    '\$${stats.costPerItem}',
                    Colors.green.shade700,
                    Icons.monetization_on,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Category Breakdown
              if (stats.categoryBreakdown.isNotEmpty)
                _buildModernCategoryBreakdown(stats),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatSection(String title, IconData icon, Color color, List<Widget> statItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: statItems,
        ),
      ],
    );
  }

  Widget _buildModernStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCategoryBreakdown(ListStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.category, size: 20, color: Colors.orange),
            ),
            SizedBox(width: 8),
            Text(
              '🏷️ Category Breakdown',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: stats.topCategories.map((entry) {
              final percentage = stats.getCategoryPercentage(entry.key);
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${(percentage * 100).round()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '(${entry.value})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: percentage,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade500,
                                    Colors.orange.shade700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchStatus() {
    if (_isSearching) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Smart searching...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '"${_searchController.text}"',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_lastSearchType == SearchResultType.autoAdd) {
      return SizedBox();
    }

    if (_lastSearchType == SearchResultType.noResults && _scoredResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
              ),
              SizedBox(height: 16),
              Text(
                'No products found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try a different search term or use a template',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome, color: Colors.blue, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Smart Template Detected!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              '🎯 $description',
              style: TextStyle(
                fontSize: 15,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: keywords.map((keyword) => Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  keyword,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isAddingTemplate ? null : () => _addTemplateProducts(templateName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
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
                          Icon(Icons.auto_awesome, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Add $templateName products',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  height: 50,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _detectedTemplate = null;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_scoredResults.isEmpty || _detectedTemplate != null) return SizedBox();

    final sortedResults = SmartSearchService.getSortedMatches(_scoredResults);

    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Text(
              'Search Results (${sortedResults.length})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sortedResults.length,
              itemBuilder: (context, index) {
                final scoredProduct = sortedResults[index];
                return _buildScoredSearchResultItem(scoredProduct);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoredSearchResultItem(ScoredProduct scoredProduct) {
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
          ),
          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              product.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shopping_bag, size: 24, color: Colors.green),
                );
              },
            ),
          )
              : Center(
            child: Icon(Icons.shopping_bag, size: 24, color: Colors.green),
          ),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            if (product.category != null)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Category: ${product.category}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.white, size: 18),
                onPressed: () => _addProduct(product),
                padding: EdgeInsets.all(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchasedCount = _items.where((item) => item.isPurchased).length;
    final totalCount = _items.length;
    final progressPercentage = totalCount > 0 ? purchasedCount / totalCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.shoppingList.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.green.shade800.withOpacity(0.3),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.analytics),
              onPressed: _toggleStats,
              tooltip: 'Statistics',
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.add),
              onPressed: _toggleSearch,
              tooltip: _showSearch ? 'Close Search' : 'Add Items',
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadListDetails,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          if (_showSearch)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search products to add',
                      hintText: 'Type product name or template...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.green.shade400, width: 2),
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          _scoredResults.clear();
                          _detectedTemplate = null;
                          setState(() {});
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: _searchProducts,
                    autofocus: true,
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),

          // Statistics Card
          if (!_showSearch) _buildStatisticsCard(),

          // Search Status
          if (_showSearch) _buildSearchStatus(),

          // Template Suggestion
          if (_showSearch && _detectedTemplate != null) _buildTemplateSuggestion(),

          // Search Results
          if (_showSearch && _scoredResults.isNotEmpty) _buildSearchResults(),

          // Progress Header
          if (!_showSearch && _scoredResults.isEmpty && _items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade50,
                    Colors.blue.shade50,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Progress text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shopping Progress',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        '${(progressPercentage * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Progress bar
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: progressPercentage,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade500,
                                  Colors.green.shade700,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Progress details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$purchasedCount/$totalCount items purchased',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        '${totalCount - purchasedCount} remaining',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Items List or Empty State
          if (!_showSearch || _scoredResults.isEmpty)
            Expanded(
              flex: _showSearch ? 0 : 1,
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading your list...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              )
                  : _items.isEmpty
                  ? Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade400),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No items in this list',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the + button to add products',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32),
                      Container(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _toggleSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 32),
                          ),
                          child: Text(
                            'Add Products',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildListItem(item);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListItem(ShoppingListItem item) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: item.isPurchased ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: item.isPurchased ? Colors.green.shade100 : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: item.isPurchased ? Colors.green.shade100 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isPurchased ? Colors.green.shade200 : Colors.blue.shade100,
            ),
          ),
          child: Checkbox(
            value: item.isPurchased,
            onChanged: (value) => _toggleItemPurchased(item),
            activeColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: BorderSide(color: Colors.grey.shade400),
          ),
        ),
        title: Text(
          item.productName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration: item.isPurchased ? TextDecoration.lineThrough : TextDecoration.none,
            color: item.isPurchased ? Colors.grey.shade500 : Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.price != null)
              Text(
                '\$${item.price!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: item.isPurchased ? Colors.grey.shade400 : Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            SizedBox(height: 8),
            _buildQuantityControls(item),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            onPressed: () => _removeItem(item),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControls(ShoppingListItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.remove, size: 18, color: Colors.grey.shade700),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => _updateItemQuantity(item, item.quantity - 1),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              item.quantity.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.add, size: 18, color: Colors.grey.shade700),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => _updateItemQuantity(item, item.quantity + 1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }
}