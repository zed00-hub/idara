# ذاكرة المشروع الشاملة - تطبيق نظمها (Nadmha POS)
> **تاريخ التوثيق:** 2026-11-05  
> **الإصدار:** 1.0.0 (MVP & Complete Offline POS)  
> **المنصة المستهدفة:** Flutter (Android أولاً، قابل للتوسع لـ iOS و Desktop)  
> **بيئة العمل:** يعمل 100% دون إنترنت (Offline-First) بالكامل دون خوادم أو APIs خارجية.  
> **حالة المشروع:** تم بناء وتطبيق واختبار كافة المكونات بنجاح (All Tests Passed - 0 Errors).

---

## 📌 الفلسفة العامة والميزات الجوهرية

تطبيق **نظمها** هو نظام نقاط بيع (POS) وإدارة متاجر بقالة ومحلات تجارية صُمم خصيصاً ليناسب طبيعة السوق الجزائري. يتميز بالسرعة القصوى، السهولة، ودعم كامل للعمليات غير المتصلة بالإنترنت.

---

## 🛠️ المعمارية والتقنيات المختارة

1. **إدارة الحالة (State Management):**
   - نمط `Provider` + `ChangeNotifier` لهيكلة واضحة وخفيفة الأداء.
2. **قواعد البيانات المحلية والتخزين:**
   - **SQLite (`sqflite` & `sqflite_common_ffi`)**: لقاعدة المنتجات الكبرى (كتالوج 42,010 منتج جزائري مسبق التحميل ومفهرس)، الفواتير، ديون الزبائن، وسجل المبيعات والمشتريات.
   - **SharedPreferences**: للإعدادات العامة، مفاتيح الأمان والـ PIN، بيانات المتجر، وحالة الإعداد الأولي.
3. **التصميم والهوية البصرية (UI/UX):**
   - يدعم الوضعين: **Light Mode** و **Dark Mode**.
   - ألوان الهوية: أزرق داكن احترافي (`#1A237E`) كلون رئيسي، وأخضر زمردي (`#00BFA5`) كلون ثانوي وأزرار التأكيد.
   - الخط المعتمد: **Cairo** (عبر `google_fonts`).
   - واجهة متجاوبة ومصممة للهواتف بالدرجة الأولى (Mobile-First) تدعم اتجاه اليمين لليسار (RTL) مع الفرنسية.
4. **اللغات:**
   - ثنائي اللغة: **العربية** (افتراضي) + **الفرنسية**.

---

## 📂 الهيكلية البرمجية للملفات (Project Structure)

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         # لوحة الألوان الاحترافية (Navy & Emerald)
│   │   ├── app_strings.dart        # قاموس الترجمة للعربية والفرنسية
│   │   └── app_theme.dart          # سمات Material 3 للوضعين الفاتح والداكن بخط Cairo
│   ├── database/
│   │   └── db_helper.dart          # إدارة SQLite ونسخ قاعدة الكتالوج 42k من assets
│   ├── services/
│   │   ├── audio_service.dart      # تشغيل صوت صفارة الباركود (Beep)
│   │   ├── backup_service.dart     # تصدير واستيراد النسخ الاحتياطية JSON وملفات Excel/CSV
│   │   ├── print_service.dart      # الطباعة الحرارية ومشاركة الفواتير والنواقص عبر WhatsApp
│   │   └── storage_service.dart    # تخزين إعدادات المحل ورموز الأمان PIN
│   └── utils/
│       └── currency_formatter.dart # تنسيق الدينار الجزائري وتقريب الفكة لأقرب 5 دج
├── models/
│   ├── product.dart                # نموذج السلعة
│   ├── cart_item.dart              # عنصر السلة وتفاصيل التسعير
│   ├── invoice.dart                # نموذج الفاتورة
│   ├── customer.dart               # نموذج الزبون ورصيد الكريدي
│   ├── supplier.dart               # نموذج المورد
│   ├── expense.dart                # نموذج المصاريف
│   └── cash_register.dart          # نموذج صندوق المال اليومي
├── providers/
│   ├── app_settings_provider.dart  # إعدادات التطبيق والأمان
│   ├── pos_provider.dart           # محرك الكاشير والسلة وحساب الفكة
│   ├── inventory_provider.dart     # إدارة والبحث في 42,000 سلعة
│   ├── customer_debt_provider.dart # إدارة ديون الزبائن وسندات القبض
│   ├── supplier_provider.dart      # إدارة الموردين وفواتير الشراء
│   └── financial_report_provider.dart # الصندوق اليومي والمصاريف وتقرير Z
├── screens/
│   ├── onboarding/
│   │   └── onboarding_screen.dart  # شاشة الترحيب والإعداد الأولي
│   ├── pos/
│   │   ├── pos_screen.dart         # شاشة الكاشير (35% كاميرا + 65% سلة وفاتورة)
│   │   ├── checkout_dialog.dart    # نافذة الدفع (نقدي/كريدي/جزئي وتقريب 5 دج)
│   │   └── invoice_success_sheet.dart # خيارات ما بعد البيع (طباعة/واتساب)
│   ├── inventory/
│   │   ├── inventory_screen.dart   # شاشة استعراض وبحث وتصنيف السلع
│   │   └── product_form_dialog.dart# نافذة إضافة/تعديل سلعة مع ماسح الباركود
│   ├── invoices/
│   │   └── invoice_history_screen.dart # أرشيف الفواتير وتفاصيلها وإعادة طباعتها
│   ├── debts/
│   │   └── customer_debts_screen.dart  # سجل ديون الزبائن وتذكير واتساب
│   ├── suppliers/
│   │   └── suppliers_screen.dart   # سجل الموردين وفواتير الجملة
│   ├── reports/
│   │   └── financial_reports_screen.dart # تقرير Z-Report وإدارة الصندوق والمصاريف
│   ├── settings/
│   │   ├── settings_screen.dart    # إعدادات المحل، النسخ الاحتياطي، المظهر
│   │   └── pin_lock_dialog.dart    # نافذة التحقق من PIN للأقسام المحمية
│   └── main_navigation_screen.dart # شريط التنقل السفلي والتحكم الذكي بزر الرجوع
└── main.dart                       # نقطة انطلاق التطبيق وتجهيز المزودات
```

---

## 📊 قاعدة البيانات المدمجة
- ملف القاعدة: `assets/database/products_catalog.db` (حجم: 6.86 MB).
- عدد السلع: **42,010 منتج جزائري** بباركوداتها وتسمياتها وأسعار التجزئة والجملة.
- مفهرسة بالكامل على حقلي `barcode` و `name` للاستجابة اللحظية (أقل من 10ms للبحث).
- صوت الماسح: `assets/audio/beep.wav` نغمة 1200Hz مدمجة.
