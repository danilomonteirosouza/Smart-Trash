class DeviceAck {
  const DeviceAck({required this.commandId, required this.action, required this.status, required this.detail});
  final String commandId;
  final String action;
  final String status;
  final String detail;

  factory DeviceAck.fromJson(Map<String, dynamic> json) => DeviceAck(
        commandId: json['commandId']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
      );
}
