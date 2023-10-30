import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:sail_ui/sail_ui.dart';
import 'package:sidesail/logger.dart';
import 'package:sidesail/rpc/rpc.dart';
import 'package:sidesail/withdrawals.dart';
import 'package:stacked/stacked.dart';

// TODO: the legacy testchain GUI uses the term SCO for sidechain BTC. A bit
// confusing? They are bitcoin, after all. Need to find a nice term.
// SBTC?

@RoutePage()
class WithdrawalPage extends StatelessWidget {
  const WithdrawalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SailPage(
      title: 'Withdraw',
      body: ViewModelBuilder.reactive(
        viewModelBuilder: () => WithdrawalPageViewModel(),
        builder: ((context, viewModel, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your sidechain balance: ${viewModel.sidechainBalance} SCO',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  onChanged: ((value) {
                    viewModel.withdrawalAddress = value;
                  }),
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Mainchain Bitcoin Address',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Withdrawal',
                          suffixText: 'SCO',
                        ),
                        inputFormatters: [
                          // digits plus dot
                          FilteringTextInputFormatter.allow(RegExp(r'[.0-9]')),
                        ],
                        onChanged: (value) {
                          // TODO: this doesn't update the final cost value...
                          viewModel.withdrawalAmount = double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        initialValue: viewModel.mainchainFee.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Mainchain Fee',
                          suffixText: 'SCO',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  readOnly: true,
                  initialValue: viewModel.transactionFee.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Transaction Fee',
                    suffixText: 'SCO',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Total cost:'),
                    const SizedBox(width: 10),
                    Text(
                      '${(viewModel.withdrawalAmount + viewModel.mainchainFee + viewModel.transactionFee)} SCO',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    viewModel.onWithdraw(context);
                  },
                  child: const Text('Withdraw'),
                ),
                // TODO: this just caps the table...
                const SingleChildScrollView(
                  child: SizedBox(
                    height: 300, // TODO: how to get this number
                    child: Withdrawals(),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class WithdrawalPageViewModel extends MultipleFutureViewModel {
  RPC get _rpc => GetIt.I.get<RPC>();

  // TODO: how to take this on creation? Async operation, possible
  // to sync this with global state somehow? Pls help, BO
  double get sidechainBalance => dataMap?[_SidechainBalanceFuture];

  double withdrawalAmount = 0.0;
  double get transactionFee => dataMap?[_SidechainFeeFuture];

  // TODO: estimate this
  final double mainchainFee = 0.001;

  String withdrawalAddress = '';

  Timer? balanceTimer;

  WithdrawalPageViewModel() {
    balanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // fetchAndUpdateBalance();
    });
  }

  @override
  Map<String, Future Function()> get futuresMap => {
        _SidechainFeeFuture: estimateSidechainFee,
        _SidechainBalanceFuture: _rpc.getBalance,
      };

  Future<double> estimateSidechainFee() async {
    final estimate = await _rpc.callRAW('estimatesmartfee', [6]) as Map<String, dynamic>;
    if (estimate.containsKey('errors')) {
      log.w("could not estimate fee: ${estimate["errors"]}");
    }

    final btcPerKb = estimate.containsKey('feerate') ? estimate['feerate'] as double : 0.0001; // 10 sats/byte

    // Who knows!
    const kbyteInWithdrawal = 5;

    return btcPerKb * kbyteInWithdrawal;
  }

  void onWithdraw(BuildContext context) async {
    // 1. Get refund address. This can be any address we control on the SC.
    final refund = await _rpc.callRAW('getnewaddress', ['Sidechain withdrawal refund']) as String;

    log.d('got refund address: $refund');

    // 3. Get MC fee
    // This happens with the `getaveragemainchainfees` RPC. This
    // is passed straight on to the mainchain `getaveragefee`,
    // which is added in the Drivechain implementation of Bitcoin
    // Core.
    // This, as opposed to `estimatesmartfee`, is used is because
    // we need everyone to get the same results for withdrawal
    // bundle validation.
    //
    // The above might not actually be correct... What's the best
    // way of doing this?

    final address = withdrawalAddress;

    // Because the function is async, the view might disappear/unmount
    // by the time it's used. The linter doesn't like that, and wants
    // you to check whether the view is mounted before using it
    if (!context.mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm withdrawal'),
        content: Text(
          'Confirm withdrawal: $withdrawalAmount BTC to $address for $transactionFee SC fee and $mainchainFee MC fee',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Pop the currently visible dialog
              Navigator.of(context).pop();

              // This creates a new dialog on success
              _doWithdraw(
                context,
                address,
                refund,
                withdrawalAmount,
                transactionFee,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // TODO: add error case popup
  void _doWithdraw(
    BuildContext context,
    String address,
    String refund,
    double amount,
    double sidechainFee,
  ) async {
    log.i(
      'doing withdrawal: $amount BTC to $address for $sidechainFee SC fee and $mainchainFee MC fee',
    );

    // TODO: how do we update the balance and reset the fields here?
    final withdrawalTxid = await _rpc.callRAW('createwithdrawal', [
      address,
      refund,
      amount,
      sidechainFee,
      mainchainFee,
    ]);

    log.i('txid: $withdrawalTxid');

    if (!context.mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(
          'Submitted withdrawal successfully! TXID: $withdrawalTxid',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

const _SidechainFeeFuture = 'sidechainFee';
const _SidechainBalanceFuture = 'sidechainBalance';