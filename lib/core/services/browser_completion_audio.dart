import 'dart:js_interop';

@JS('pageClockAudio.prepare')
external JSPromise<JSAny?> _prepare();
@JS('pageClockAudio.play')
external JSPromise<JSAny?> _play(JSString url);
@JS('pageClockAudio.stop')
external void stop();

Future<void> prepare() async => await _prepare().toDart.then((_) {});
Future<void> play(String url) async => await _play(url.toJS).toDart.then((_) {});
