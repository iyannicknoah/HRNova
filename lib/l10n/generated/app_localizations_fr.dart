// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get language => 'Langue';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navEmployees => 'Employés';

  @override
  String get navAttendance => 'Présence';

  @override
  String get navLeave => 'Congés';

  @override
  String get navPayroll => 'Paie';

  @override
  String get navPerformance => 'Performance';

  @override
  String get navReports => 'Rapports';

  @override
  String get navNovaAi => 'Nova AI';

  @override
  String get navRecruitment => 'Recrutement';

  @override
  String get navBranches => 'Succursales';

  @override
  String get navDepartments => 'Départements';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get lightMode => 'Mode clair';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get logOutTitle => 'Se déconnecter ?';

  @override
  String get logOutMessage =>
      'Voulez-vous vraiment vous déconnecter de votre compte ?';

  @override
  String get logOutConfirm => 'Déconnexion';

  @override
  String get cancel => 'Annuler';

  @override
  String get loginStarting => 'Démarrage de HRNovva…';

  @override
  String get loginWelcomeBack => 'Bon retour';

  @override
  String get loginSubtitle => 'Connectez-vous à votre compte';

  @override
  String get loginEmailLabel => 'Adresse e-mail';

  @override
  String get loginEmailRequired => 'Veuillez saisir votre adresse e-mail';

  @override
  String get loginPasswordLabel => 'Mot de passe';

  @override
  String get loginPasswordRequired => 'Veuillez saisir votre mot de passe';

  @override
  String get loginSignIn => 'Se connecter';

  @override
  String get suspTitle => 'Compte suspendu';

  @override
  String get suspBody =>
      'Le compte HRNovva de votre entreprise a été suspendu. Cela peut être dû à un problème de facturation ou à une violation des conditions d\'utilisation.';

  @override
  String get suspSignOut => 'Se déconnecter';
}
