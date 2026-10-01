import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/role_access_config.dart';
import 'package:kologsoft/screens/dashboard_settings.dart';
import 'package:provider/provider.dart';

import '../models/account_type_model.dart';
import '../providers/routes.dart';
import 'account_type_reg.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({Key? key}) : super(key: key);

  ListTile _buildSubAccountTile(BuildContext context, String accountClass) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        Icons.circle,
        color: colorScheme.onSurfaceVariant,
        size: 10,
      ),
      title: Text(accountClass, style: TextStyle(color: colorScheme.onSurface)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountTypeReg(
              account: AccountTypeModel(accountClass: accountClass),
            ),
          ),
        );
      },
    );
  }

  bool _isSalesUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('sales');
  }

  bool _isCashier(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('cashier');
  }

  bool _isWarehouseUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('warehouse') ||
        normalized.contains('stock officer');
  }

  bool _isAdminUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    final adminRoles = ['admin', 'superadmin', 'manager'];
    return adminRoles.any((role) => normalized.contains(role));
  }

  bool _isSuperAdminUser(String accessLevel) {
    final normalized = accessLevel.toLowerCase().replaceAll(' ', '');
    return normalized.contains('superadmin');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final colorScheme = Theme.of(context).colorScheme;
        final isSales = _isSalesUser(value.accesslevel);
        final isCashier = _isCashier(value.accesslevel);
        final isWarehouse = _isWarehouseUser(value.accesslevel);
        final isAdmin = _isAdminUser(value.accesslevel);
        final isSuperAdmin = _isSuperAdminUser(value.accesslevel);
        // Navigate to sales page directly for sales users
        if (isSales) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, Routes.sales);
          });
          return const SizedBox.shrink();
        }

        if (isCashier) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, Routes.cashierPage);
          });
          return const SizedBox.shrink();
        }

        if (isWarehouse) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, Routes.warehousehomescreen);
          });
          return const SizedBox.shrink();
        }

        return Drawer(
          backgroundColor: colorScheme.surface,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: colorScheme.surface),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.factory, size: 48, color: colorScheme.onSurface),
                    const SizedBox(height: 8),
                    Text(
                      value.company.toString().toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),



              if (isAdmin || isSuperAdmin)
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    unselectedWidgetColor: colorScheme.onSurface,
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: colorScheme.surfaceContainerHighest,
                      onPrimary: colorScheme.onSurface,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.dashboard,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Dashboard',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    selectedTileColor: colorScheme.surfaceContainerHighest,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

              if (isAdmin) ...[
                if (value.hasFeature('user_management')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(Icons.people, color: colorScheme.onSurface),
                    title: Text(
                      'User Management',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('register_staff'))
                        ListTile(
                          leading: Icon(
                            Icons.person_add,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Register Staff',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.staffreg);
                          },
                        ),
                      if (value.hasFeature('view_staff'))
                        ListTile(
                          leading: Icon(
                            Icons.people_outline,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Staff',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.staffView);
                          },
                        ),
                      if (value.hasFeature('role_access_config'))
                        ListTile(
                          leading: Icon(
                            Icons.admin_panel_settings,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Role Access Config',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RoleAccessConfigScreen(),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                // System Setup
                if (value.companyid == 'KS008') ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(
                      Icons.agriculture_outlined,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Farmer Management',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.person_add_alt_1,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'Farmer Registration',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.farmerreg);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.people_alt,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'View Farmers',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.viewfarmers);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.grass,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'Crop Registration',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.registercrop);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.language,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'Register Language',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.registerlanguage);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.cast_for_education,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'Education Level',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.educationlevel);
                        },
                      ),
                    ],
                  ),

                  Divider(color: colorScheme.outlineVariant),
                ],
                if (value.companyid != 'KS008') ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(Icons.groups_2, color: colorScheme.onSurface),
                    title: Text(
                      'Customer Management',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.person_add_alt,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'Customer Registration',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.customerreg);
                        },
                      ),

                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],
                if (value.hasFeature('item')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(
                      Icons.inventory_2,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Item',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('item_category'))
                        ListTile(
                          leading: Icon(
                            Icons.category,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Item Category',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.productcatereg);
                          },
                        ),
                      if (value.hasFeature('register_item'))
                        ListTile(
                          leading: Icon(
                            Icons.add_box,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Register Item ',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.itemreg);
                          },
                        ),
                      if (value.hasFeature('view_item'))
                        ListTile(
                          leading: Icon(
                            Icons.view_list,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'view',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.itemlist);
                          },
                        ),
                      if (value.hasFeature('branch_price'))
                        ListTile(
                          leading: Icon(
                            Icons.price_change,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Branch Price',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.branchprice);
                          },
                        ),
                      if (value.hasFeature('print_barcode'))
                        ListTile(
                          leading: Icon(
                            Icons.qr_code_2,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Print Barcode',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.printbarcodes);
                          },
                        ),
                      if (value.hasFeature('bundle_item'))
                        ListTile(
                          leading: Icon(
                            Icons.redeem,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Bundle Item',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.bundlesale);
                          },
                        ),
                      if (value.hasFeature('view_bundle'))
                        ListTile(
                          leading: Icon(
                            Icons.sync_alt,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Bundle view',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.bundlesaleview);
                          },
                        ),
                      if (value.hasFeature('item_balance_sync'))
                        ListTile(
                          leading: Icon(
                            Icons.cached,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Item balance Sync',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.stockbalancesync,
                            );
                          },
                        ),
                      if (value.hasFeature('synczero'))
                        ListTile(
                          leading: Icon(
                            Icons.sync,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Sync Item to Zero',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.synczero);
                          },
                        ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                // Stock Management
                if (value.hasFeature('stock_management')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(Icons.storage, color: colorScheme.onSurface),
                    title: Text(
                      'Stock Management',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('new_stock_entry'))
                        ListTile(
                          leading: Icon(
                            Icons.post_add,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'New Stock Entry ',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.newstock);
                          },
                        ),
                      if (value.hasFeature('view_stock_entries'))
                        ListTile(
                          leading: Icon(
                            Icons.fact_check,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Stock Entries ',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.stocklisttable);
                          },
                        ),
                      // if(value.hasFeature('view_stock'))
                      // ListTile(
                      //   leading: Icon(
                      //     Icons.add_business,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'View Stock ',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.stocklist);
                      //   },
                      // ),
                      if (value.hasFeature('view_transfers'))
                        ListTile(
                          leading: Icon(
                            Icons.local_shipping,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Transfers',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.transfers);
                          },
                        ),
                      if (value.hasFeature('view_transfer_list'))
                        ListTile(
                          leading: Icon(
                            Icons.swap_horiz,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Transfer List',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.transferlist);
                          },
                        ),
                      if (value.hasFeature('view_stock_transfers'))
                        // ListTile(
                        //   leading: Icon(
                        //     Icons.add_business,
                        //     color: colorScheme.onSurface,
                        //   ),
                        //   title: Text(
                        //     'View Transfer List',
                        //     style: TextStyle(color: colorScheme.onSurface),
                        //   ),
                        //   onTap: () {
                        //     Navigator.pushNamed(context, Routes.stocktransferlist);
                        //   },
                        // ),
                        ListTile(
                          leading: Icon(
                            Icons.security_update_good_sharp,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Stock Adjustment',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.stocktake);
                          },
                        ),

                      // ListTile(
                      //   leading: Icon(
                      //     Icons.add_business,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Requests',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.stockrequest);
                      //   },
                      // ),
                      // ListTile(
                      //   leading: Icon(
                      //     Icons.add_business,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Requests List',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.stockrequestlist);
                      //   },
                      // ),
                      // ListTile(
                      //   leading: Icon(
                      //     Icons.add_business,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Receive Stock',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.receivestock);
                      //   },
                      // ),
                      // ListTile(
                      //   leading: Icon(
                      //     Icons.add_business,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Supply',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.stocksupply);
                      //   },
                      // ),
                      if (value.hasFeature('purchase_returns'))
                        ListTile(
                          leading: Icon(
                            Icons.assignment_return,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Purchase returns',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.purchaseReturns,
                            );
                          },
                        ),
                      if (value.hasFeature('view_purchase_returns'))
                        ListTile(
                          leading: Icon(
                            Icons.history,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Purchase returns',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.purchaseReturnsView,
                            );
                          },
                        ),
                      if (value.hasFeature('warehouse_supply'))
                        ListTile(
                          leading: Icon(
                            Icons.warehouse_outlined,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Warehouse Supply',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.warehousehomescreen,
                            );
                          },
                        ),
                      // ListTile(
                      //   leading: Icon(
                      //     Icons.receipt_long,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Transaction Supply Report',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.transactionsupplyreport);
                      //   },
                      // ),
                      if (value.hasFeature('deleted_stock'))
                        ListTile(
                          leading: Icon(
                            Icons.delete_sweep,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Deleted stock',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.deletedstock);
                          },
                        ),

                      // ListTile(
                      //   leading: Icon(
                      //     Icons.upload_file,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Upload stock',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.uploadstock);
                      //   },
                      // ),
                      // ListTile(
                      //   leading: Icon(
                      //     Icons.transfer_within_a_station,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Upload stock transfers',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.uploadstocktransfer);
                      //   },
                      // ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                // Transactions
                if (value.hasFeature('transactions')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(
                      Icons.receipt_long,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Transactions',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('sales'))
                        ListTile(
                          leading: Icon(
                            Icons.point_of_sale,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Sales ',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.sales);
                          },
                        ),
                      if (value.hasFeature('cashier'))
                        ListTile(
                          leading: Icon(
                            Icons.payments,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Cashier ',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.cashierPage);
                          },
                        ),
                      if (value.hasFeature('sales_view'))
                        ListTile(
                          leading: Icon(
                            Icons.manage_search,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Sales view',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.salesview);
                          },
                        ),
                      if (value.hasFeature('close_sale'))
                        ListTile(
                          leading: Icon(
                            Icons.task_alt,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Close Sale',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.closesale);
                          },
                        ),
                      if (value.hasFeature('discount'))
                        ListTile(
                          leading: Icon(
                            Icons.discount,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Discount',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.discountmanager,
                            );
                          },
                        ),
                      if (value.hasFeature('discount_view'))
                        ListTile(
                          leading: Icon(
                            Icons.loyalty,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Discount view',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.discountmanagerview,
                            );
                          },
                        ),
                    ],
                  ),

                  Divider(color: colorScheme.outlineVariant),
                ],

                if (value.hasFeature('account')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(
                      Icons.calculate,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Account',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('chart_of_accounts'))
                        ListTile(
                          leading: Icon(
                            Icons.account_tree,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Chart of Accounts',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.coa);
                          },
                        ),
                      if (value.hasFeature('activity_chart'))
                        ListTile(
                          leading: Icon(
                            Icons.insights,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Activity Chart',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.activityChartReg,
                            );
                          },
                        ),
                      if (value.hasFeature('payment_accounts'))
                        ListTile(
                          leading: Icon(
                            Icons.credit_card,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Payment Accounts',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.paymentaccounts,
                            );
                          },
                        ),
                      if (value.hasFeature('payment_duration'))
                        ListTile(
                          leading: Icon(
                            Icons.event,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Payment Duration',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.paymentdurationreg,
                            );
                          },
                        ),
                      if (value.hasFeature('creditor_openbal'))
                        ListTile(
                          leading: Icon(
                            Icons.money_off,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Creditors Open Balance',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.creditopenbal);
                          },
                        ),
                      if (value.hasFeature('creditor_openbalview'))
                        ListTile(
                          leading: Icon(
                            Icons.summarize,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Creditors Balance',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.creditopenbalview,
                            );
                          },
                        ),
                      if (value.hasFeature('creditor_payable'))
                        ListTile(
                          leading: Icon(
                            Icons.outbound,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Account Payable',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.creditorpayable,
                            );
                          },
                        ),
                      if (value.hasFeature('view_account_payable'))
                        ListTile(
                          leading: Icon(
                            Icons.assignment,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Account Payable',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.creditorpayableview,
                            );
                          },
                        ),
                      if (value.hasFeature('receivables'))
                        ListTile(
                          leading: Icon(
                            Icons.request_quote,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Receivables',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.debtorlist);
                          },
                        ),
                      if (value.hasFeature('receivables'))
                        ListTile(
                          leading: Icon(
                            Icons.price_check,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Receive Payments',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.receivepayments,
                            );
                          },
                        ),
                      if (value.hasFeature('view_receivables'))
                        ListTile(
                          leading: Icon(
                            Icons.assignment_turned_in,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Receivables',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.debtpayments);
                          },
                        ),
                      if (value.hasFeature('debtor_bal'))
                        ListTile(
                          leading: Icon(
                            Icons.person_search,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Debtors Balance',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.debtorBal);
                          },
                        ),
                      if (value.hasFeature('bank_transfer'))
                        ListTile(
                          leading: Icon(
                            Icons.currency_exchange,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Bank transfer',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.banktransfer);
                          },
                        ),
                      if (value.hasFeature('banktransferview'))
                        ListTile(
                          leading: Icon(
                            Icons.manage_history,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Bank transfer view',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.banktransferview,
                            );
                          },
                        ),
                      if (value.hasFeature('journal_entry'))
                        ListTile(
                          leading: Icon(
                            Icons.menu_book,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Journal',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.journalEntry);
                          },
                        ),
                      if (value.hasFeature('journal_view'))
                        ListTile(
                          leading: Icon(
                            Icons.article,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Journal',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.journalView);
                          },
                        ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                if (value.hasFeature('expenses')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(
                      Icons.shopping_cart,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Expenses',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('entry_expense'))
                        ListTile(
                          leading: Icon(
                            Icons.paid,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Expense Entry ',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.expense);
                          },
                        ),
                      if (value.hasFeature('view_expense'))
                        ListTile(
                          leading: Icon(
                            Icons.receipt,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'View Expenses',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.expenseview);
                          },
                        ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                if (value.hasFeature('reports')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(
                      Icons.bar_chart,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Reports',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('stock_report'))
                        ListTile(
                          leading: Icon(
                            Icons.analytics,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Stock Report',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.stockreport);
                          },
                        ),

                      if (value.hasFeature('sales_report'))
                        ListTile(
                          leading: Icon(
                            Icons.query_stats,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Sales Report',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.salesreport);
                          },
                        ),

                      if (value.hasFeature('general_ledger'))
                        ListTile(
                          leading: Icon(
                            Icons.account_balance,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'General Ledger',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.generalledger);
                          },
                        ),
                      if (value.hasFeature('profit_and_loss'))
                        ListTile(
                          leading: Icon(
                            Icons.trending_up,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Profit and Loss',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.profitAndLoss);
                          },
                        ),

                      if (value.hasFeature('sales_invoice'))
                        ListTile(
                          leading: Icon(
                            Icons.description,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Sales Invoice',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.salesinvoice);
                          },
                        ),

                      if (value.hasFeature('debtor_report'))
                     ListTile(
                          leading: Icon(
                            Icons.account_balance_wallet,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Debtor Report',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.debtorreport);
                          },
                        ),

                      ListTile(
                        leading: Icon(
                          Icons.account_balance_wallet,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'Supplier Report',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, Routes.supplierreport);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.warehouse,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'Warehouse Supply Report',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            Routes.transactionsupplyreport,
                          );
                        },
                      ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                // Damages & Sales Returns
                if (value.hasFeature('damages')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(Icons.warning, color: colorScheme.onSurface),
                    title: Text(
                      'Damages',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('register_damage'))
                        ListTile(
                          leading: Icon(
                            Icons.broken_image,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Register Damage',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.damages);
                          },
                        ),
                      if (value.hasFeature('damagelist'))
                        ListTile(
                          leading: Icon(
                            Icons.playlist_remove,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Damages list',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.damagelist);
                          },
                        ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                if (value.hasFeature('sales_return')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(Icons.business, color: colorScheme.onSurface),
                    title: Text(
                      'Sales Return',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('return_sales'))
                        ListTile(
                          leading: Icon(
                            Icons.list_alt,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Return Sales',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.salesreturn);
                          },
                        ),
                      if (value.hasFeature('sales_return_view'))
                        ListTile(
                          leading: Icon(
                            Icons.list,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'View Sales return',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.salesreturnlist,
                            );
                          },
                        ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                if (value.hasFeature('uploads')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(
                      Icons.upload_file,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      'Uploads',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('receipt_upload'))
                        ListTile(
                          leading: Icon(
                            Icons.folder_open,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Receipt',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.uploadreceipt);
                          },
                        ),
                      if (value.hasFeature('receipt_upload_view'))
                        ListTile(
                          leading: Icon(
                            Icons.receipt_long_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            'Receipt view',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.uploadreceiptview,
                            );
                          },
                        ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                if (value.hasFeature('system_setup')) ...[
                  ExpansionTile(
                    iconColor: colorScheme.onSurface,
                    collapsedIconColor: colorScheme.onSurface,
                    leading: Icon(Icons.settings, color: colorScheme.onSurface),
                    title: Text(
                      'System Setup',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    children: [
                      if (value.hasFeature('supplier_registration'))
                        ListTile(
                          leading: Icon(
                            Icons.storefront,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Supplier Registration',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.supplierreg);
                          },
                        ),
                      if (value.hasFeature('branch_registration'))
                        ListTile(
                          leading: Icon(
                            Icons.add_location_alt,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Branch Registration',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.branchreg);
                          },
                        ),
                      if (value.hasFeature('return_damage_reasons'))
                        ListTile(
                          leading: Icon(
                            Icons.edit_note,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Return/Damage reasons',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, Routes.returnreasons);
                          },
                        ),

                      if (value.hasFeature('add_community'))
                        ListTile(
                          leading: Icon(
                            Icons.add,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'Add Community',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.registercommunity,
                            );
                          },
                        ),
                      if (value.hasFeature('sms_setup'))
                        ListTile(
                          leading: Icon(
                            Icons.sms,
                            color: colorScheme.onSurface,
                          ),
                          title: Text(
                            'SMS Setup',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.SmsConfiguration,
                            );
                          },
                        ),
                      ListTile(
                        leading: Icon(
                          Icons.data_exploration,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(
                          'collection Manager',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            Routes.collectionmanager,
                          );
                        },
                      ),

                      if (isAdmin || isSuperAdmin)
                        ListTile(
                          leading: Icon(Icons.tune, color: colorScheme.onSurface),
                          title: Text(
                            'Dashboard & Feature Settings',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DashboardSettings(),
                              ),
                            );
                          },
                        ),

                      // ListTile(
                      //   leading: Icon(
                      //     Icons.graphic_eq,
                      //     color: colorScheme.onSurface,
                      //   ),
                      //   title: Text(
                      //     'Usage Stats',
                      //     style: TextStyle(color: colorScheme.onSurface),
                      //   ),
                      //   onTap: () {
                      //     Navigator.pushNamed(context, Routes.firebasestats);
                      //   },
                      // ),
                    ],
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],

                //SMS Management
                if (value.hasFeature('sms-management')) ...[
                  ListTile(
                    leading: Icon(Icons.campaign, color: colorScheme.onSurface),
                    title: Text(
                      'SMS Management',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, Routes.smsManagement);
                    },
                  ),
                  Divider(color: colorScheme.outlineVariant),
                ],


                 ListTile(
                  leading: Icon(Icons.login, color: colorScheme.onSurface),
                  title: Text(
                    'logout',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  onTap: () async {
                    await value.logout(context);
                  },
                ),
              ],

            ],
          ),
        );
      },
    );
  }
}
