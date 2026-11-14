import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/printbarcodemodel.dart';
import '../providers/Datafeed.dart';
import '../providers/item_provider.dart';

class PrintBarcodes extends StatefulWidget {
  const PrintBarcodes({super.key});

  @override
  State<PrintBarcodes> createState() => _PrintBarcodesState();
}

class _PrintBarcodesState extends State<PrintBarcodes> {
  final TextEditingController controller = TextEditingController(text: "10");
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  int count = 20;
  int countr = 35;
  String searchQuery = "";
  bool _showSearch = false;
  bool _preparingPrint = false;

  // paging (desktop table)
  int currentPage = 0;
  final int rowsPerPage = 20;

  @override
  void initState() {
    super.initState();
    final datafeed = context.read<Datafeed>();
    Future.microtask(datafeed.fetchProducts);
  }

  @override
  void dispose() {
    controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<ProductModel> _filteredItems(List<ProductModel> items) {
    return context.read<ItemProvider>().filterBarcodeProducts(
      items,
      searchQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Datafeed>();
    final width = MediaQuery.of(context).size.width;
    final filteredItems = _filteredItems(provider.products);
    final colorScheme = Theme.of(context).colorScheme;
    final searchIconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : colorScheme.onSurfaceVariant;
    bool isDesktop(double width) => width > 700;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                cursorColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : colorScheme.primary,
                onChanged: (value) => setState(() {
                  searchQuery = value.toLowerCase();
                  currentPage = 0;
                }),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search, color: searchIconColor),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              )
            : const Text('Products'),
        actions: [
          IconButton(
            tooltip: _showSearch ? 'Close search' : 'Search products',
            icon: Icon(
              _showSearch ? Icons.close : Icons.search,
              color: searchIconColor,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  searchQuery = '';
                  currentPage = 0;
                }
              });
              if (_showSearch) _searchFocusNode.requestFocus();
            },
          ),
        ],
        bottom: _preparingPrint
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: provider.loadingproducts
          ? const Center(child: CircularProgressIndicator())
          : provider.products.isEmpty
          ? const Center(child: Text("No products"))
          : Column(
              children: [
                Expanded(
                  child: provider.loadingproducts
                      ? const Center(child: CircularProgressIndicator())
                      : filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            "No items registered yet",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : isDesktop(width)
                      ? _buildTable(filteredItems)
                      : _buildMobileList(filteredItems),
                ),
              ],
            ),
    );
  }

  //  Desktop
  Widget _buildTable(List<ProductModel> filteredItems) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final totalPages = (filteredItems.length / rowsPerPage).ceil().clamp(
      1,
      999999,
    );
    if (currentPage > totalPages - 1) currentPage = totalPages - 1;
    if (currentPage < 0) currentPage = 0;

    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, filteredItems.length);
    final pageItems = filteredItems.sublist(start, end);

    const colNo = 70.0;
    const colName = 240.0;
    const colCategory = 180.0;
    const colCode = 180.0;
    const colBarcode = 100.0;
    const colQr = 100.0;

    Widget headerCell(String text, double w) => SizedBox(
      width: w,
      child: Text(
        text,
        style: TextStyle(
          color: isLightTheme ? colorScheme.onSurface : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            // header
            Container(
              color: isLightTheme
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: colNo,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: headerCell("No", colNo - 12),
                      ),
                    ),
                    headerCell("Name", colName),
                    headerCell("Category", colCategory),
                    headerCell("Code", colCode),
                    headerCell("Barcode", colBarcode),
                    headerCell("QR Code", colQr),
                  ],
                ),
              ),
            ),
            //  const Divider(height: 1, color: Colors.white24),

            // rows
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width:
                      colNo +
                      colName +
                      colCategory +
                      colCode +
                      colBarcode +
                      colQr,
                  child: ListView.builder(
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) {
                      final p = pageItems[index];
                      final barcode = (p.barcode).isEmpty ? p.name : p.barcode;
                      final rowNo = start + index + 1;

                      return Container(
                        decoration: BoxDecoration(
                          color: isLightTheme
                              ? colorScheme.surface
                              : const Color(0xFF0D1B2A),
                          border: Border(
                            bottom: BorderSide(
                              color: isLightTheme
                                  ? colorScheme.outlineVariant
                                  : colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: colNo,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  "$rowNo",
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: colName,
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  color: isLightTheme
                                      ? colorScheme.onSurface
                                      : Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: colCategory,
                              child: Text(
                                p.category,
                                style: TextStyle(
                                  color: isLightTheme
                                      ? colorScheme.onSurfaceVariant
                                      : Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: colCode,
                              child: Text(
                                barcode,
                                style: TextStyle(
                                  color: isLightTheme
                                      ? colorScheme.onSurfaceVariant
                                      : Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: colBarcode,
                              child: InkWell(
                                onTap: _preparingPrint
                                    ? null
                                    : () => _runPrint(() => previewBarcode(p)),
                                child: Icon(
                                  Icons.barcode_reader,
                                  size: 40,
                                  color: isLightTheme
                                      ? colorScheme.primary
                                      : Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: colQr,
                              child: InkWell(
                                onTap: _preparingPrint
                                    ? null
                                    : () => _runPrint(() => previewQR(p)),
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  size: 40,
                                  color: isLightTheme
                                      ? colorScheme.primary
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // paging controls
            Container(
              color: isLightTheme
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: isLightTheme
                          ? colorScheme.onSurfaceVariant
                          : Colors.white,
                    ),
                    onPressed: currentPage > 0
                        ? () => setState(() => currentPage--)
                        : null,
                  ),
                  Text(
                    "Page ${currentPage + 1} of $totalPages",
                    style: TextStyle(
                      color: isLightTheme
                          ? colorScheme.onSurface
                          : Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: isLightTheme
                          ? colorScheme.onSurfaceVariant
                          : Colors.white,
                    ),
                    onPressed: currentPage < totalPages - 1
                        ? () => setState(() => currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  Mobile
  Widget _buildMobileList(List<ProductModel> filteredItems) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredItems.length,
      itemBuilder: (_, index) {
        final p = filteredItems[index];
        final barcode = (p.barcode).isEmpty ? p.name : p.barcode;

        return Card(
          color: isLightTheme ? colorScheme.surface : const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isLightTheme
                  ? colorScheme.outlineVariant
                  : Colors.transparent,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // NAME + CATEGORY (takes remaining space)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLightTheme
                              ? colorScheme.onSurface
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.category,
                        style: TextStyle(
                          color: isLightTheme
                              ? colorScheme.onSurfaceVariant
                              : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // BARCODE ICON
                InkWell(
                  onTap: _preparingPrint
                      ? null
                      : () => _runPrint(() => previewBarcode(p)),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.barcode_reader,
                      size: 28,
                      color: isLightTheme
                          ? colorScheme.primary
                          : Colors.white70,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // QR ICON (optional)
                InkWell(
                  onTap: _preparingPrint
                      ? null
                      : () => _runPrint(() => previewQR(p)),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.qr_code_scanner,
                      size: 28,
                      color: isLightTheme
                          ? colorScheme.primary
                          : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runPrint(Future<void> Function() printAction) async {
    setState(() => _preparingPrint = true);
    try {
      await printAction();
    } finally {
      if (mounted) {
        setState(() => _preparingPrint = false);
      }
    }
  }

  Future<void> previewBarcode(ProductModel product) async {
    final filename = '${product.company}_${product.name}.pdf';
    final itemProvider = context.read<ItemProvider>();
    final fonts = await Future.wait([
      rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      rootBundle.load('assets/fonts/RobotoMono-Regular.ttf'),
    ]);
    final data = await itemProvider.buildBarcodePdf(
      product: product,
      labelCount: count,
      regularFont: fonts[0].buffer.asUint8List(
        fonts[0].offsetInBytes,
        fonts[0].lengthInBytes,
      ),
      boldFont: fonts[1].buffer.asUint8List(
        fonts[1].offsetInBytes,
        fonts[1].lengthInBytes,
      ),
      monoFont: fonts[2].buffer.asUint8List(
        fonts[2].offsetInBytes,
        fonts[2].lengthInBytes,
      ),
    );
    await Printing.layoutPdf(name: filename, onLayout: (_) async => data);
  }

  Future<void> previewQR(ProductModel product) async {
    final filename = '${product.company}_${product.name}.pdf';
    final itemProvider = context.read<ItemProvider>();
    final fonts = await Future.wait([
      rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    ]);
    final data = await itemProvider.buildQrCodePdf(
      product: product,
      labelCount: countr,
      regularFont: fonts[0].buffer.asUint8List(
        fonts[0].offsetInBytes,
        fonts[0].lengthInBytes,
      ),
      boldFont: fonts[1].buffer.asUint8List(
        fonts[1].offsetInBytes,
        fonts[1].lengthInBytes,
      ),
    );
    await Printing.layoutPdf(name: filename, onLayout: (_) async => data);
  }
}
