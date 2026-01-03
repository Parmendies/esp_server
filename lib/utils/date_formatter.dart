import 'dart:io';

String formatImageDate(File file) {
  try {
    final filename = file.path.split('/').last;
    var dateStr = filename.replaceAll('image_', '').replaceAll('.jpg', '');

    final parts = dateStr.split('T');
    if (parts.length != 2) return 'Tarih bilinmiyor';

    final datePart = parts[0];
    var timePart = parts[1];

    if (timePart.contains('.')) {
      timePart = timePart.split('.')[0];
    }

    final timeSegments = timePart.split('-');
    if (timeSegments.length < 3) return 'Tarih bilinmiyor';

    final properTime =
        '${timeSegments[0]}:${timeSegments[1]}:${timeSegments[2]}';
    final isoString = '${datePart}T$properTime';

    final datetime = DateTime.parse(isoString);

    final months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final day = datetime.day.toString().padLeft(2, '0');
    final month = months[datetime.month - 1];
    final year = datetime.year;
    final hour = datetime.hour.toString().padLeft(2, '0');
    final minute = datetime.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute';
  } catch (e) {
    return 'Tarih bilinmiyor';
  }
}
