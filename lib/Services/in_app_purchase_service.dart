import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';

class InAppPurchaseService {
  static final InAppPurchaseService instance = InAppPurchaseService._init();
  
  InAppPurchaseService._init();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _purchasePending = false;
  String? _queryProductError;

  // Product IDs - Replace these with your actual product IDs from Google Play Console / App Store Connect
  static const String monthlyProductId = 'premium_monthly';
  static const String quarterlyProductId = 'premium_quarterly';
  static const String yearlyProductId = 'premium_yearly';

  static const Set<String> _productIds = {
    monthlyProductId,
    quarterlyProductId,
    yearlyProductId,
  };

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get purchasePending => _purchasePending;
  String? get queryProductError => _queryProductError;

  /// Initialize the in-app purchase service
  Future<void> initialize() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    
    if (!_isAvailable) {
      final platform = Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Unknown';
      log('In-app purchase is not available on $platform');
      return;
    }

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        log('Purchase stream error: $error');
        _queryProductError = 'Purchase stream error: $error';
      },
    );

    // Load products
    await loadProducts();
  }

  /// Load available products
  Future<void> loadProducts() async {
    if (!_isAvailable) {
      _queryProductError = 'In-app purchase is not available';
      return;
    }

    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);

      if (response.error != null) {
        _queryProductError = response.error!.message;
        log('Error loading products: ${response.error!.message}');
        return;
      }

      if (response.productDetails.isEmpty) {
        _queryProductError = 'No products found';
        log('No products found');
        return;
      }

      _products = response.productDetails;
      _queryProductError = null;
      log('Loaded ${_products.length} products');
    } catch (e) {
      _queryProductError = 'Error loading products: $e';
      log('Error loading products: $e');
    }
  }

  /// Get product details by product ID
  ProductDetails? getProductById(String productId) {
    try {
      return _products.firstWhere(
        (product) => product.id == productId,
      );
    } catch (e) {
      log('Product not found: $productId');
      return null;
    }
  }

  /// Purchase a product
  /// Works for both Android and iOS subscriptions
  Future<bool> purchaseProduct(String productId) async {
    if (!_isAvailable) {
      log('In-app purchase is not available');
      return false;
    }

    final ProductDetails? productDetails = getProductById(productId);
    if (productDetails == null) {
      log('Product not found: $productId');
      return false;
    }

    if (_purchasePending) {
      log('Purchase already in progress');
      return false;
    }

    try {
      _purchasePending = true;
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // For subscriptions, use buyNonConsumable
      // This works for both Android and iOS subscriptions
      // Android: Handles auto-renewing subscriptions
      // iOS: Handles auto-renewable subscriptions via StoreKit
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      log('Purchase initiated for $productId on ${Platform.isAndroid ? 'Android' : 'iOS'}');
      return true;
    } catch (e) {
      log('Error purchasing product: $e');
      _purchasePending = false;
      return false;
    }
  }

  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        log('Purchase pending: ${purchaseDetails.productID}');
        _purchasePending = true;
      } else {
        _purchasePending = false;
        
        if (purchaseDetails.status == PurchaseStatus.error) {
          log('Purchase error: ${purchaseDetails.error}');
          _handlePurchaseError(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _handlePurchaseSuccess(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          log('Purchase canceled: ${purchaseDetails.productID}');
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Handle successful purchase
  /// Works for both Android and iOS
  void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) {
    final platform = Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Unknown';
    log('Purchase successful: ${purchaseDetails.productID} on $platform');
    log('Purchase ID: ${purchaseDetails.purchaseID}');
    log('Transaction date: ${purchaseDetails.transactionDate}');
    
    // TODO: Save purchase status to local storage/database
    // TODO: Update user premium status
    // TODO: Notify listeners
  }

  /// Handle purchase error
  /// Provides platform-specific error information
  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    final platform = Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Unknown';
    final errorMessage = purchaseDetails.error?.message ?? 'Unknown error';
    log('Purchase error on $platform: $errorMessage');
    
    if (purchaseDetails.error != null) {
      log('Error code: ${purchaseDetails.error?.code}');
      log('Error details: ${purchaseDetails.error?.details}');
    }
    
    // TODO: Show error to user
  }

  /// Restore purchases
  /// Works for both Android and iOS
  /// Android: Restores purchases from Google Play
  /// iOS: Restores purchases from App Store
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      log('In-app purchase is not available');
      return;
    }

    try {
      final platform = Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Unknown';
      log('Restoring purchases on $platform...');
      await _inAppPurchase.restorePurchases();
      log('Restore purchases initiated successfully');
    } catch (e) {
      log('Error restoring purchases: $e');
      rethrow;
    }
  }

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    // TODO: Implement subscription status check
    // This should check local storage/database for active subscription
    return false;
  }

  /// Dispose resources
  void dispose() {
    _subscription.cancel();
  }
}

