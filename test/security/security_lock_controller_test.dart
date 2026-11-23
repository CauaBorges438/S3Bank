import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/core/security/security_lock_controller.dart';

void main() {
  late DateTime now;
  late SecurityLockController controller;

  setUp(() {
    now = DateTime(2026, 1, 1, 10);
    controller = SecurityLockController(
      inactivityTimeout: const Duration(minutes: 3),
      now: () => now,
    );
  });

  tearDown(() => controller.dispose());

  test('não bloqueia se voltou antes do limite de inatividade', () {
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(controller.isLocked, isFalse);
  });

  test('bloqueia ao voltar depois do limite de inatividade', () {
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(controller.isLocked, isTrue);
  });

  test('oculta o conteúdo em segundo plano e libera ao voltar', () {
    controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(controller.isObscured, isTrue);

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.isObscured, isFalse);
  });

  test('lockOnLaunch bloqueia imediatamente', () {
    controller.lockOnLaunch();
    expect(controller.isLocked, isTrue);
  });
}
