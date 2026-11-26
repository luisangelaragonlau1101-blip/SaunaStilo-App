import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/services/firebase_attendance_service.dart';
void main(){
 test('requesting manual attendance cannot bypass the profile GPS policy',()async{
  var locations=0;
  final proof=await AttendanceDeviceProof.prepare(profile:{'asistenciaManualPermitida':false},request:{'manual':true},readLocation:()async{locations++;return {'latitud':19.4,'longitud':-99.1};});
  expect(locations,1);expect(proof['manual'],isFalse);expect(proof['latitud'],19.4);
 });
 test('explicit manual permission does not fabricate a coordinate',()async{
  final proof=await AttendanceDeviceProof.prepare(profile:{'asistenciaManualPermitida':true},request:{},readLocation:()async=>throw StateError('Must not request location'));
  expect(proof,{'manual':true});
 });
 test('a changed account during location lookup prevents the write',()async{
  String? current='worker';var writes=0;
  final service=FirebaseAttendanceService(currentUid:()=>current,readProfile:(_)async=>{'activo':true},readLocation:()async{current='other';return {'latitud':19.4,'longitud':-99.1};},invoke:(_)async{writes++;return {};});
  await expectLater(service.call('attendance-record',{'movement':'entrada'}),throwsStateError);expect(writes,0);
 });
 test('a failed server operation does not silently become a local attendance',()async{
  var writes=0;
  final service=FirebaseAttendanceService(currentUid:()=>'worker',readProfile:(_)async=>{'activo':true,'asistenciaManualPermitida':true},invoke:(_)async{writes++;throw StateError('server denied');});
  await expectLater(service.call('attendance-record',{'movement':'entrada','requestId':'stable-operation'}),throwsStateError);expect(writes,1);
 });
}
