import '../../../core/services/api_service.dart';

class SuperAdminService {
  static final SuperAdminService _i = SuperAdminService._();
  factory SuperAdminService() => _i;
  SuperAdminService._();

  final _api = ApiService();

  Future<Map<String, dynamic>> createCompany({
    required String name,
    required String hrAdminEmail,
    required String tempPassword,
    String contactPerson = '',
    String hrAdminPhone  = '',
    String address       = '',
    String tinNumber     = '',
    String industry      = 'Other',
    String companyType   = 'single',
    int monthlyPrice     = 0,
    int employeeCount    = 0,
    String? firstBranchName,
    String? firstBranchLocation,
    String? firstBranchCode,
  }) async {
    final res = await _api.post('/api/companies/create', data: {
      'name':          name,
      'hrAdminEmail':  hrAdminEmail,
      'tempPassword':  tempPassword,
      'contactPerson': contactPerson,
      'hrAdminPhone':  hrAdminPhone,
      'address':       address,
      'tinNumber':     tinNumber,
      'industry':      industry,
      'companyType':   companyType,
      'monthlyPrice':  monthlyPrice,
      'employeeCount': employeeCount,
      if (firstBranchName     != null) 'firstBranchName':     firstBranchName,
      if (firstBranchLocation != null) 'firstBranchLocation': firstBranchLocation,
      if (firstBranchCode     != null) 'firstBranchCode':     firstBranchCode,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> updateCompany(String id, Map<String, dynamic> fields) async {
    await _api.put('/api/companies/$id', data: fields);
  }

  Future<void> updateStatus(String id, String status) async {
    await _api.put('/api/companies/$id/status', data: {'status': status});
  }

  Future<void> deleteCompany(String id) async {
    await _api.delete('/api/companies/$id');
  }

  Future<void> addPayment({
    required String companyId,
    required String date,
    required int amount,
    String method    = 'bank_transfer',
    String reference = '',
  }) async {
    await _api.post('/api/companies/$companyId/payment', data: {
      'date': date, 'amount': amount,
      'method': method, 'reference': reference,
    });
  }

  Future<Map<String, dynamic>> addBranch({
    required String companyId,
    required String name,
    String location          = '',
    String code              = '',
    String? branchAdminEmail,
    String? branchAdminPassword,
    String? branchAdminName,
  }) async {
    final res = await _api.post('/api/companies/$companyId/branches', data: {
      'name': name,
      'location': location,
      'code': code,
      if (branchAdminEmail    != null) 'branchAdminEmail':    branchAdminEmail,
      if (branchAdminPassword != null) 'branchAdminPassword': branchAdminPassword,
      if (branchAdminName     != null) 'branchAdminName':     branchAdminName,
    });
    return res.data as Map<String, dynamic>;
  }
}
