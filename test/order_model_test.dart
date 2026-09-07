// تحليل صفوف الطلبات كما يردّها الخادم فعلاً.
//
// **لماذا هذا الاختبار موجود:** كان `estimatedDeliveryTime` يُقرأ `as String?`
// والعمود في القاعدة `Int?`. والتعيين التلقائي يكتب ٦٠ — فكل طلبٍ عُيّن
// تلقائياً كان يرمي `TypeError`، والرمية تخرج من `map` فتُلغي **القائمة
// كلها**. النتيجة: سائقٌ يرى «لا توجد طلبات جاهزة للاستلام» وثلاثة طلبات
// تنتظره في القاعدة، ولا خطأ ظاهر في أي مكان.
//
// العيّنة أدناه منسوخة من ردّ الإنتاج بحرفه، لا مُختلَقة.

import 'package:flutter_test/flutter_test.dart';
import 'package:sham_delivery/models/order_model.dart';

Map<String, dynamic> sampleRow({Object? estimated = 60}) => {
      'id': 'cmtq62uyz0001vz02jvll0d12',
      'orderNumber': 'ORD-MTQ62UYR-30',
      'customerName': 'Your Love',
      'customerPhone': '0957665455',
      'status': 'ready',
      // أعدادٌ صحيحة لا كسرية — JSON يفكّها `int` لا `double`
      'total': 550,
      'subtotal': 550,
      'discountAmount': 0,
      'deliveryFee': 0,
      'isPaid': false,
      'paymentMethod': 'cash',
      'orderType': 'delivery',
      'deliveryAddress': 'البرامكة، دمشق',
      'deliveryLat': 33.506682,
      'deliveryLng': 36.290889,
      'estimatedDeliveryTime': estimated,
      'createdAt': '2026-09-06T18:50:29.579Z',
      'isAvailable': false,
      'orderItems': const <dynamic>[],
    };

void main() {
  group('DeliveryOrder.fromJson', () {
    test('يقبل الزمن المتوقّع عدداً صحيحاً — وهو ما يرسله الخادم', () {
      final order = DeliveryOrder.fromJson(sampleRow());

      expect(order.estimatedDeliveryTime, 60);
      expect(order.status, 'ready');
      expect(order.awaitingPickup, isTrue);
      expect(order.total, 550.0);
    });

    test('يقبل غيابه ونصّه أيضاً', () {
      expect(DeliveryOrder.fromJson(sampleRow(estimated: null)).estimatedDeliveryTime, isNull);
      expect(DeliveryOrder.fromJson(sampleRow(estimated: '45')).estimatedDeliveryTime, 45);
      expect(DeliveryOrder.fromJson(sampleRow(estimated: 'abc')).estimatedDeliveryTime, isNull);
    });

    test('الطلب الجاهز يقع في تبويب «الجديدة»', () {
      final rows = [sampleRow(), sampleRow(), sampleRow()];
      final orders = rows.map(DeliveryOrder.fromJson).toList();

      final newTab = orders.where((o) => o.status == 'ready' || o.status == 'pending');
      expect(newTab.length, 3, reason: 'ثلاثة طلبات جاهزة يجب أن تظهر، لا أن تُلغى القائمة');
    });

    test('صفرُ الإحداثيات يُقرأ غياباً لا نقطةً في خليج غينيا', () {
      final row = sampleRow()..['deliveryLat'] = 0..['deliveryLng'] = 0;
      final order = DeliveryOrder.fromJson(row);

      expect(order.deliveryLat, isNull);
      expect(order.hasDropPoint, isFalse);
    });
  });
}
