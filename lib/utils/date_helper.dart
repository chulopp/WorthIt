import 'package:intl/intl.dart';

class DateHelper {
  static bool isCurrentMonth(String dateString) {
    if (dateString.isEmpty) return false;
    DateTime? dt;
    try {
      // Try parsing standard ISO format like "2026-05-14"
      dt = DateTime.parse(dateString);
    } catch (e) {
      // Try parsing formats like "08 Mei 2026"
      try {
        final Map<String, String> monthNames = {
          'Januari': '01', 'Februari': '02', 'Maret': '03',
          'April': '04', 'Mei': '05', 'Juni': '06',
          'Juli': '07', 'Agustus': '08', 'September': '09',
          'Oktober': '10', 'November': '11', 'Desember': '12',
          'Jan': '01', 'Feb': '02', 'Mar': '03',
          'Apr': '04', 'May': '05', 'Jun': '06',
          'Jul': '07', 'Aug': '08', 'Sep': '09',
          'Oct': '10', 'Nov': '11', 'Dec': '12',
        };
        
        String standardizedDate = dateString;
        monthNames.forEach((key, value) {
          standardizedDate = standardizedDate.replaceAll(key, value);
        });
        
        final parts = standardizedDate.split(' ');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1];
          final year = parts[2];
          dt = DateTime.parse('$year-$month-$day');
        }
      } catch (e2) {
        return false;
      }
    }
    
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.month == now.month && dt.year == now.year;
  }
}
