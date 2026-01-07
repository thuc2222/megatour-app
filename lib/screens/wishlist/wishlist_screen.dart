// lib/screens/wishlist/wishlist_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../models/service_models.dart';
import 'package:megatour_app/utils/context_extension.dart';

class WishlistScreen extends StatefulWidget {
  WishlistScreen({Key? key}) : super(key: key);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wishlistProvider = context.watch<WishlistProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.myWishlist),
        actions: [
          if (wishlistProvider.wishlist.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => _showClearDialog(context),
            ),
        ],
      ),
      body: wishlistProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : wishlistProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16),
                      Text(wishlistProvider.errorMessage!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => wishlistProvider.loadWishlist(),
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                )
              : wishlistProvider.wishlist.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            context.l10n.yourWishlistIsEmpty,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            context.l10n.saveItemsYouLikeToFindThemEasilyLater,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(context.l10n.startExploring),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => wishlistProvider.loadWishlist(),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: wishlistProvider.wishlist.length,
                        itemBuilder: (context, index) {
                          final service = wishlistProvider.wishlist[index];
                          return _buildWishlistCard(service, wishlistProvider);
                        },
                      ),
                    ),
    );
  }

  Widget _buildWishlistCard(
    ServiceModel service,
    WishlistProvider wishlistProvider,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/service-detail',
            arguments: {
              'id': service.id,
              'type': 'hotel', // You might want to store service type
            },
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              width: 120,
              height: 120,
              color: Colors.grey[300],
              child: service.image != null
                  ? Image.network(
                      service.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(Icons.image, size: 40),
                        );
                      },
                    )
                  : Center(
                      child: Icon(Icons.image, size: 40),
                    ),
            ),
            
            // Details
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    
                    if (service.address != null)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              service.address!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (service.reviewScore != null)
                          Row(
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              SizedBox(width: 2),
                              Text(
                                service.reviewScore ?? "0.0",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        if (service.price != null)
                          Text(
                            '\$${service.price ?? "0"}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Remove button
            IconButton(
              icon: Icon(Icons.favorite, color: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.removeFromWishlist),
                    content: Text(
                      context.l10n.areYouSureYouWantToRemoveThisItemFromYourWishlist,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.remove),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final success = await wishlistProvider.removeFromWishlist(
                    serviceType: 'hotel', // You might want to store this
                    serviceId: service.id,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Removed from wishlist'
                              : 'Failed to remove from wishlist',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.clearWishlist),
        content: Text(
          context.l10n.areYouSureYouWantToRemoveAllItemsFromYourWishlist,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final wishlistProvider = context.read<WishlistProvider>();
              final success = await wishlistProvider.clearWishlist();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Wishlist cleared'
                          : 'Failed to clear wishlist',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.clearAll),
          ),
        ],
      ),
    );
  }
}