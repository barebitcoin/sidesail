import 'package:get_it/get_it.dart';
import 'package:sidesail/config/sidechains.dart';
import 'package:sidesail/providers/balance_provider.dart';
import 'package:sidesail/providers/proc_provider.dart';
import 'package:sidesail/providers/transactions_provider.dart';
import 'package:sidesail/routing/router.dart';
import 'package:sidesail/rpc/rpc_ethereum.dart';
import 'package:sidesail/rpc/rpc_mainchain.dart';
import 'package:sidesail/rpc/rpc_sidechain.dart';
import 'package:sidesail/rpc/rpc_testchain.dart';
import 'package:sidesail/storage/client_settings.dart';
import 'package:sidesail/storage/secure_store.dart';

// register all global dependencies, for use in views, or in view models
// each dependency can only be registered once
Future<void> initGetitDependencies(Sidechain initialChain) async {
  final mainFuture = MainchainRPCLive.create();
  await _initSidechainRPC(initialChain);
  final mainRPC = await mainFuture;

  GetIt.I.registerLazySingleton<MainchainRPC>(
    () => mainRPC,
  );

  GetIt.I.registerLazySingleton<AppRouter>(
    () => AppRouter(),
  );

  GetIt.I.registerLazySingleton<ClientSettings>(
    () => ClientSettings(store: SecureStore()),
  );

  GetIt.I.registerLazySingleton<BalanceProvider>(
    // by registering an instance of the balance provider,
    // we start polling for balance updates
    () => BalanceProvider(),
  );

  GetIt.I.registerLazySingleton(() => ProcessProvider());

  GetIt.I.registerLazySingleton<TransactionsProvider>(
    () => TransactionsProvider(),
  );
}

// register all rpc connections. We attempt to create all
// rpcs in parallell, so they're ready instantly when swapping
// we can also query the balance
Future<void> _initSidechainRPC(Sidechain chain) async {
  final ethFuture = EthereumRPCLive.create();
  final testFuture = TestchainRPCLive.create();

  final ethRPC = await ethFuture;
  final testRPC = await testFuture;

  GetIt.I.registerLazySingleton<TestchainRPC>(
    () => testRPC,
  );
  GetIt.I.registerLazySingleton<EthereumRPC>(
    () => ethRPC,
  );

  SidechainSubRPC sidechainSubRPC;
  switch (chain.type) {
    case SidechainType.testChain:
      sidechainSubRPC = testRPC;
      break;

    case SidechainType.ethereum:
      sidechainSubRPC = ethRPC;
      break;
  }

  GetIt.I.registerLazySingleton<SidechainRPC>(
    () => SidechainRPC(subRPC: sidechainSubRPC),
  );
}
