// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_delete_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AutoDeleteService)
final autoDeleteServiceProvider = AutoDeleteServiceProvider._();

final class AutoDeleteServiceProvider
    extends $NotifierProvider<AutoDeleteService, void> {
  AutoDeleteServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoDeleteServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoDeleteServiceHash();

  @$internal
  @override
  AutoDeleteService create() => AutoDeleteService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$autoDeleteServiceHash() => r'2f5100a4852f7f82921231b057ca856658e136cc';

abstract class _$AutoDeleteService extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
