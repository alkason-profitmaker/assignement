/**
 * Order History Screen - View past orders
 */
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/RootNavigator';
import { ordersAPI } from '../services/api';

type OrderHistoryScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'OrderHistory'>;
};

interface Order {
  id: number;
  order_number: string;
  status: string;
  total_pages: number;
  bw_pages: number;
  color_pages: number;
  total_amount: number;
  created_at: string;
  printed_at?: string;
  rating?: number;
}

export default function OrderHistoryScreen({ navigation }: OrderHistoryScreenProps) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  useEffect(() => {
    loadOrders();
  }, []);

  const loadOrders = async (pageNum: number = 1, refresh: boolean = false) => {
    try {
      if (refresh) {
        setRefreshing(true);
      } else if (pageNum === 1) {
        setIsLoading(true);
      }

      const response = await ordersAPI.getOrders(pageNum, 10);
      const newOrders = response.data.orders;

      if (refresh || pageNum === 1) {
        setOrders(newOrders);
      } else {
        setOrders([...orders, ...newOrders]);
      }

      setHasMore(newOrders.length === 10);
      setPage(pageNum);
    } catch (error) {
      console.error('Failed to load orders:', error);
    } finally {
      setIsLoading(false);
      setRefreshing(false);
    }
  };

  const handleRefresh = () => {
    loadOrders(1, true);
  };

  const handleLoadMore = () => {
    if (hasMore && !isLoading) {
      loadOrders(page + 1);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return '#4CAF50';
      case 'ready_to_print':
        return '#FF9800';
      case 'printing':
        return '#2196F3';
      case 'failed':
      case 'expired':
        return '#F44336';
      case 'refunded':
        return '#9C27B0';
      default:
        return '#999';
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const handleOrderPress = (order: Order) => {
    if (order.status === 'ready_to_print') {
      navigation.navigate('QRScanner', { orderNumber: order.order_number });
    } else if (order.status === 'printing') {
      navigation.navigate('PrintStatus', { orderNumber: order.order_number });
    }
  };

  const renderOrder = ({ item }: { item: Order }) => (
    <TouchableOpacity
      style={styles.orderCard}
      onPress={() => handleOrderPress(item)}
      disabled={!['ready_to_print', 'printing'].includes(item.status)}
    >
      <View style={styles.orderHeader}>
        <Text style={styles.orderNumber}>#{item.order_number}</Text>
        <View style={[styles.statusBadge, { backgroundColor: getStatusColor(item.status) }]}>
          <Text style={styles.statusText}>{item.status.replace('_', ' ')}</Text>
        </View>
      </View>

      <View style={styles.orderDetails}>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Pages:</Text>
          <Text style={styles.detailValue}>
            {item.total_pages} ({item.bw_pages} B/W
            {item.color_pages > 0 ? ` + ${item.color_pages} Color` : ''})
          </Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Amount:</Text>
          <Text style={styles.detailValue}>₹{item.total_amount}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Date:</Text>
          <Text style={styles.detailValue}>{formatDate(item.created_at)}</Text>
        </View>
      </View>

      {item.rating && (
        <View style={styles.ratingRow}>
          <Text style={styles.ratingLabel}>Rating:</Text>
          <Text style={styles.ratingStars}>
            {'★'.repeat(item.rating)}
            {'☆'.repeat(5 - item.rating)}
          </Text>
        </View>
      )}

      {item.status === 'ready_to_print' && (
        <View style={styles.actionHint}>
          <Text style={styles.actionHintText}>Tap to scan QR and print</Text>
        </View>
      )}
    </TouchableOpacity>
  );

  const renderEmpty = () => (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyIcon}>📋</Text>
      <Text style={styles.emptyTitle}>No Orders Yet</Text>
      <Text style={styles.emptyText}>Your print orders will appear here</Text>
      <TouchableOpacity
        style={styles.printButton}
        onPress={() => navigation.navigate('FileUpload')}
      >
        <Text style={styles.printButtonText}>Start Printing</Text>
      </TouchableOpacity>
    </View>
  );

  const renderFooter = () => {
    if (!hasMore) return null;
    return (
      <View style={styles.footer}>
        <ActivityIndicator size="small" color="#2196F3" />
      </View>
    );
  };

  if (isLoading && orders.length === 0) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  return (
    <FlatList
      style={styles.container}
      data={orders}
      renderItem={renderOrder}
      keyExtractor={(item) => item.order_number}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
      }
      onEndReached={handleLoadMore}
      onEndReachedThreshold={0.5}
      ListEmptyComponent={renderEmpty}
      ListFooterComponent={renderFooter}
      contentContainerStyle={orders.length === 0 ? styles.emptyList : undefined}
    />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  orderCard: {
    backgroundColor: '#fff',
    margin: 16,
    marginBottom: 8,
    padding: 16,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  orderHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  orderNumber: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 4,
  },
  statusText: {
    fontSize: 12,
    color: '#fff',
    fontWeight: '600',
    textTransform: 'capitalize',
  },
  orderDetails: {
    borderTopWidth: 1,
    borderTopColor: '#f0f0f0',
    paddingTop: 12,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  detailLabel: {
    fontSize: 14,
    color: '#666',
  },
  detailValue: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  ratingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#f0f0f0',
  },
  ratingLabel: {
    fontSize: 14,
    color: '#666',
    marginRight: 8,
  },
  ratingStars: {
    fontSize: 16,
    color: '#FFC107',
  },
  actionHint: {
    marginTop: 12,
    padding: 8,
    backgroundColor: '#E3F2FD',
    borderRadius: 4,
    alignItems: 'center',
  },
  actionHintText: {
    fontSize: 12,
    color: '#1976D2',
  },
  emptyList: {
    flex: 1,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  emptyText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 24,
  },
  printButton: {
    backgroundColor: '#2196F3',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  printButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  footer: {
    padding: 16,
    alignItems: 'center',
  },
});
