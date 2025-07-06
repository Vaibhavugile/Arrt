import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:async';
import 'package:art/screens/AddProductScreen.dart';
import 'package:art/screens/EditProductScreen.dart';
import 'package:art/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ProductScreen extends StatefulWidget {
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> filteredProducts = [];
  late String branchCode;
  String searchQuery = '';
  String selectedSubcategory = 'All';
  List<String> subcategories = ['All'];
  int itemsPerPage = 10;
  int currentPage = 1;
  bool isDarkMode = false; // Add isDarkMode state to ProductScreen
  int _selectedSidebarIndex = 0; // To track selected sidebar item for large screens

  StreamSubscription? _productSubscription;

  List<_ProductActionItem> getProductActions(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
      _ProductActionItem(loc.addProduct, Icons.add, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => AddProductScreen()));
      }),
      _ProductActionItem(loc.exportToPdf, Icons.download, () => exportToPDF(context, filteredProducts)),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        branchCode = userProvider.branchCode!;
      });
      listenToProducts();
    });
  }

  @override
  void dispose() {
    _productSubscription?.cancel();
    super.dispose();
  }

  void listenToProducts() {
    _productSubscription = FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('products')
        .snapshots()
        .listen((snapshot) {
      final fetched = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      final uniqueSubcategories = {
        'All',
        ...fetched.map((p) => p['subcategory'].toString()).toSet()
      };

      setState(() {
        allProducts = fetched;
        subcategories = uniqueSubcategories.toList();
        applyFilters();
      });
    });
  }

  void applyFilters() {
    List<Map<String, dynamic>> result = allProducts;

    if (selectedSubcategory != 'All') {
      result =
          result.where((p) => p['subcategory'] == selectedSubcategory).toList();
    }

    if (searchQuery.isNotEmpty) {
      result = result
          .where((p) =>
          p['name']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()))
          .toList();
    }

    setState(() {
      filteredProducts = result.take(currentPage * itemsPerPage).toList();
    });
  }

  void deleteProduct(String id) async {
    await FirebaseFirestore.instance
        .collection('tables')
        .doc(branchCode)
        .collection('products')
        .doc(id)
        .delete();
  }

  void importCSV() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null) return;

    final file = result.files.first;
    final content = utf8.decode(file.bytes!);
    final csvData = CsvToListConverter().convert(content);
    final headers = csvData.first.cast<String>();
    final rows = csvData.skip(1);

    try {
      for (var row in rows) {
        final product = Map.fromIterables(headers, row);
        product['price'] = double.tryParse(product['price'].toString()) ?? 0;
        await FirebaseFirestore.instance
            .collection('tables')
            .doc(branchCode)
            .collection('products')
            .add(product);
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.csvImported)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.csvFailed)));
    }
  }

  void exportToPDF(
      BuildContext context, List<Map<String, dynamic>> filteredProducts) async {
    final pdf = pw.Document();
    final loc = AppLocalizations.of(context)!;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(loc.productExport,
                  style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: [loc.productName, loc.price, loc.subcategory],
                data: filteredProducts
                    .map((p) => [
                  p['name']?.toString() ?? '',
                  p['price']?.toString() ?? '',
                  p['subcategory']?.toString() ?? ''
                ])
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
              )
            ],
          );
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File(
        '${outputDir.path}/product_export_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${loc.pdfOpenFailed}: ${result.message}'),
      ));
    }
  }

  void loadMore() {
    setState(() {
      currentPage++;
      applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final productActions = getProductActions(context);

    // Define theme colors consistent with InventoryScreen
    final Color appBarGradientStart = Color(0xFFE0FFFF); // Muted light blue
    final Color appBarGradientMid = Color(0xFFBFEBFA);   // Steel Blue
    final Color appBarGradientEnd = Color(0xFF87CEEB);   // Dark Indigo (This is a good accent color)

    final Color lightModeCardSolidColor = Color(0xFFCBEEEE); // Changed to light grey
    final Color darkModeCardColor = Colors.grey[800]!; // Dark mode card background
    final Color lightModeCardIconColor = Colors.black87; // Dark icons
    final Color lightModeCardTextColor = Colors.black87; // Dark text
    final Color darkModeIconColor = Color(0xFF9AC0C6); // Lighter blue for dark mode icons
    final Color darkModeTextColor = Colors.white70; // Dark text

    final Color webContentBackgroundLight = Colors.white;
    final Color webContentBackgroundDark = Colors.grey[900]!;

    final Color webSelectedNavItemBackground = appBarGradientMid;
    final Color webSelectedNavItemContentColor = Colors.white;

    final Color webUnselectedNavItemColorLight = lightModeCardTextColor;
    final Color webUnselectedNavItemColorDark = darkModeTextColor;

    final Color webSidebarTitleColorLight = Colors.black87;
    final Color webSidebarTitleColorDark = Colors.white;


    return Scaffold(
      backgroundColor: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight, // Apply content background
      appBar: AppBar(
        title: Text(loc.products, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)), // Title color for contrast on gradient
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.white), // Icons color for contrast on gradient
        actions: [
          // Theme Toggle for ProductScreen as well, if it's not managed globally
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
            tooltip: loc.toggleTheme, // Assuming you have this string in app_localizations.dart
          ),
        ],
        flexibleSpace: isDarkMode
            ? Container(
          color: Colors.grey[850], // Dark mode AppBar background
        )
            : Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                appBarGradientStart,
                appBarGradientMid,
                appBarGradientEnd,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
      floatingActionButton: LayoutBuilder( // Hide FAB on large screens
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => AddProductScreen()));
            },
            child: const Icon(Icons.add),
            tooltip: loc.addProduct,
            backgroundColor: isDarkMode ? appBarGradientEnd : appBarGradientMid, // Apply theme color
            foregroundColor: Colors.white, // For the icon
          );
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth > 700;

          return Row(
              children: [
              if (isLargeScreen)
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: isDarkMode ? darkModeCardColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.15),
                  blurRadius: isDarkMode ? 8 : 10,
                  offset: Offset(0, isDarkMode ? 4 : 6),
                ),
              ],
            ),
            margin: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 16.0, 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.category,
                          color: isDarkMode
                              ? webSidebarTitleColorDark
                              : webSidebarTitleColorLight,
                          size: 24),
                      SizedBox(width: 12),
                      Text(
                        loc.products, // Changed to loc.products for product screen
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? webSidebarTitleColorDark
                              : webSidebarTitleColorLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                    color: isDarkMode ? Colors.white10 : Colors.grey[300],
                    thickness: 1,
                    height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: productActions.length,
                    itemBuilder: (context, index) {
                      final item = productActions[index];
                      final isSelected = _selectedSidebarIndex == index;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedSidebarIndex = index;
                            });
                            item.onTap();
                          },
                          hoverColor: isDarkMode
                              ? webSelectedNavItemBackground.withOpacity(0.5)
                              : webSelectedNavItemBackground.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? webSelectedNavItemBackground
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSelected
                                      ? webSelectedNavItemContentColor
                                      : (isDarkMode
                                      ? webUnselectedNavItemColorDark
                                      : webUnselectedNavItemColorLight),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? webSelectedNavItemContentColor
                                        : (isDarkMode
                                        ? webUnselectedNavItemColorDark
                                        : webUnselectedNavItemColorLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
          child: Container(
          color: isDarkMode ? webContentBackgroundDark : webContentBackgroundLight,
          child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 24 : 12), // Larger padding for web
          child: Column(
          children: [
          Card( // Wrap search and dropdown in a Card
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.only(bottom: isLargeScreen ? 24 : 12),
          color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor,
          child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
          children: [
          Expanded(
          child: TextField(
          decoration: InputDecoration(
          hintText: loc.searchHint,
          prefixIcon: Icon(Icons.search, color: isDarkMode ? darkModeIconColor : lightModeCardIconColor), // Themed icon
          border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10)),
          fillColor: isDarkMode ? Colors.grey[700] : Colors.grey[100], // Themed input field
          filled: true,
          ),
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87), // Themed text input
          onChanged: (value) {
          setState(() {
          searchQuery = value;
          applyFilters();
          });
          },
          ),
          ),
          SizedBox(width: isLargeScreen ? 24 : 12), // More space on web
          DropdownButton<String>(
          value: selectedSubcategory,
          dropdownColor: isDarkMode ? Colors.grey[700] : Colors.white, // Themed dropdown background
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87), // Themed dropdown text
          items: subcategories.map((subcategory) {
          return DropdownMenuItem(
          value: subcategory,
          child: Text(subcategory == 'All'
          ? loc.subcategoryAll
              : subcategory),
          );
          }).toList(),
          onChanged: (value) {
          setState(() {
          selectedSubcategory = value!;
          applyFilters();
          });
          },
          ),
          ],
          ),
          ),
          ),
          Expanded(
          child: filteredProducts.isEmpty
          ? Center(child: Text(loc.noProducts, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54))) // Themed empty text
              : ListView.builder(
          itemCount: filteredProducts.length + 1,
          itemBuilder: (context, index) {
          if (index == filteredProducts.length) {
          return filteredProducts.length < allProducts.length
          ? Center(
          child: TextButton(
          onPressed: loadMore,
          child: Text(loc.loadMore, style: TextStyle(color: isDarkMode ? appBarGradientMid : appBarGradientEnd)), // Themed button text
          ))
              : SizedBox.shrink();
          }

          final p = filteredProducts[index];
          return Animate(
          effects: [
          FadeEffect(duration: 400.ms),
          MoveEffect(begin: const Offset(0, 20))
          ],
          child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.symmetric(vertical: 8),
          color: isDarkMode ? darkModeCardColor : lightModeCardSolidColor, // Apply card background theme
          child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(
          p['name'],
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? darkModeTextColor : lightModeCardTextColor), // Apply text theme
          ),
          subtitle: Text('₹${p['price']} • ${p['subcategory']}', style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])), // Apply subtitle text theme
          trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          IconButton(
          icon: Icon(Icons.edit, color: isDarkMode ? darkModeIconColor : Colors.indigo), // Apply icon theme, keep indigo if distinct
          onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
          builder: (context) => EditProductScreen(
          productId: p['id'],
          branchCode: branchCode),
          ),
          ),
          ),
          IconButton(
          icon: Icon(Icons.delete, color: isDarkMode ? Colors.redAccent : Colors.red), // Apply icon theme, keep red if distinct
          onPressed: () => deleteProduct(p['id']),
          ),
          ],
          ),
          ),
          ),
          );
          },
          ),
          ),
          ],
          ),
          ),
          ),

          ),],
          );
          },
      ),
    );
  }
}

class _ProductActionItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _ProductActionItem(this.title, this.icon, this.onTap);
}