import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:sidesail/rpc/models/core_transaction.dart';
import 'package:sidesail/rpc/rpc_mainchain.dart';
import 'package:sidesail/rpc/rpc_sidechain.dart';

class TransactionsProvider extends ChangeNotifier {
  MainchainRPC get _mainchainRPC => GetIt.I.get<MainchainRPC>();
  SidechainContainer get sidechain => GetIt.I.get<SidechainContainer>();
  Logger get log => GetIt.I.get<Logger>();

  // because the class extends ChangeNotifier, any subscribers
  // to this class will be notified of changes to these
  // variables.
  List<CoreTransaction> mainchainTransactions = [];
  List<CoreTransaction> transactions = [];
  bool initialized = false;

  // used for polling
  late Timer _timer;

  TransactionsProvider() {
    fetch();
    _startPolling();
  }

  // call this function from anywhere to refetch transaction list
  Future<void> fetch() async {
    transactions = await sidechain.rpc.listTransactions();
    transactions = transactions.reversed.toList();

    mainchainTransactions = await _mainchainRPC.listTransactions();
    mainchainTransactions = mainchainTransactions.reversed.toList();

    initialized = true;

    notifyListeners();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await fetch();
        notifyListeners();
      } catch (error) {
        log.t('could not fetch transactions: $error');
      }
    });
  }

  void stopPolling() {
    // Cancel timer when provider is disposed (never?)
    _timer.cancel();
  }

  @override
  void dispose() {
    super.dispose();
    stopPolling();
  }
}
