class AttendancePoint {
  final DateTime day;
  final String status;
  const AttendancePoint(this.day,this.status);
}
class RecordedStreak {
  final int current, best, total;
  const RecordedStreak(this.current,this.best,this.total);
  int get nextMilestone {for(final n in [7,15,30,50,100]){if(n>current)return n;}return ((current~/50)+1)*50;}
  static RecordedStreak from(List<AttendancePoint> entries){
    final sorted=List<AttendancePoint>.of(entries)..sort((a,b)=>a.day.compareTo(b.day));
    final unique=<String,AttendancePoint>{};
    for(final p in sorted){unique['${p.day.year}-${p.day.month}-${p.day.day}']=p;}
    int current=0,best=0;
    for(final p in unique.values){
      if(p.status=='a_tiempo'){current++;if(current>best)best=current;}
      else if(p.status!='justificada'){current=0;}
    }
    return RecordedStreak(current,best,unique.length);
  }
}
