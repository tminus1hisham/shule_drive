import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline_sync_manager.dart';

/// Connectivity Provider
/// 
/// Monitors network connectivity state and provides offline/online status
/// to the app. Also triggers sync when connection is restored.
class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final OfflineSyncManager _syncManager = OfflineSyncManager();
  
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  bool _isOnline = false;
  bool _isSyncing = false;
  bool _hasChecked = false;
  
  // Getters
  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isSyncing => _isSyncing;

  /// Offline after the first real check; avoids flashing the offline prompt
  /// before connectivity is known.
  bool get showOfflinePrompt => _hasChecked && !_isOnline;
  
  // Connection type info - check if any connection matches
  bool get isWifi => _connectionStatus.contains(ConnectivityResult.wifi);
  bool get isMobile => _connectionStatus.contains(ConnectivityResult.mobile);
  bool get isEthernet => _connectionStatus.contains(ConnectivityResult.ethernet);
  
  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (kDebugMode) {
      print('📶 Initializing connectivity provider...');
    }
    
    // Check initial status
    final result = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(result);
    
    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    
    // Listen for sync state changes
    _syncManager.syncStateStream.listen(_onSyncStateChanged);
  }
  
  /// Update connection status
  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    _connectionStatus = results;
    _hasChecked = true;
    
    // Check if we have any connection (not just none)
    final hasConnection = results.isNotEmpty && 
        !results.every((r) => r == ConnectivityResult.none);
    
    final wasOnline = _isOnline;
    _isOnline = hasConnection;
    
    if (kDebugMode) {
      print('📶 Connectivity changed: $results (online: $_isOnline)');
    }
    
    // Notify listeners
    notifyListeners();
    
    // If we just came online, trigger sync
    if (!wasOnline && _isOnline) {
      if (kDebugMode) {
        print('🌐 Connection restored, triggering sync...');
      }
      await _triggerSync();
    }
  }
  
  /// Handle sync state changes
  void _onSyncStateChanged(SyncState state) {
    _isSyncing = state.isInProgress;
    notifyListeners();
  }
  
  /// Trigger manual sync
  Future<SyncResult> sync() async {
    return await _triggerSync();
  }
  
  Future<SyncResult> _triggerSync() async {
    if (_isSyncing) {
      return SyncResult.alreadySyncing();
    }
    
    return await _syncManager.syncPendingOperations();
  }
  
  /// Get pending operations count
  Future<int> getPendingCount() async {
    return await _syncManager.getPendingCount();
  }
  
  /// Force connectivity check
  Future<void> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(result);
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
