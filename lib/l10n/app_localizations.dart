import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ceb.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ceb'),
    Locale('en'),
    Locale('tl')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Sakay Ta'**
  String get appName;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get commonViewAll;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get commonLogout;

  /// No description provided for @commonLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get commonLanguage;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get commonNotAvailable;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get commonNoData;

  /// No description provided for @commonOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// No description provided for @commonOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get commonOnline;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get commonOptional;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get commonUpload;

  /// No description provided for @commonDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get commonDetails;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonEmpty;

  /// No description provided for @rolePassenger.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get rolePassenger;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @loginGreeting.
  ///
  /// In en, this message translates to:
  /// **'Good Morning!'**
  String get loginGreeting;

  /// No description provided for @loginSubtitlePassenger.
  ///
  /// In en, this message translates to:
  /// **'Login to start riding.'**
  String get loginSubtitlePassenger;

  /// No description provided for @loginSubtitleDriver.
  ///
  /// In en, this message translates to:
  /// **'Login to start earning.'**
  String get loginSubtitleDriver;

  /// No description provided for @loginSubtitleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Login to manage Sakay Ta.'**
  String get loginSubtitleAdmin;

  /// No description provided for @loginMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get loginMobileNumber;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginMobileHint.
  ///
  /// In en, this message translates to:
  /// **'+63 9XX XXX XXXX'**
  String get loginMobileHint;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get loginForgotPassword;

  /// No description provided for @loginLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginLoginButton;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Create one now'**
  String get loginNoAccount;

  /// No description provided for @loginLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get loginLanguageLabel;

  /// No description provided for @loginDemoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Demo Accounts'**
  String get loginDemoAccounts;

  /// No description provided for @loginDemoPassenger.
  ///
  /// In en, this message translates to:
  /// **'Passenger Demo'**
  String get loginDemoPassenger;

  /// No description provided for @loginDemoDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver Demo'**
  String get loginDemoDriver;

  /// No description provided for @loginDemoAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin Demo'**
  String get loginDemoAdmin;

  /// No description provided for @loginPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile number.'**
  String get loginPhoneRequired;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get loginPasswordRequired;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid mobile number or password.'**
  String get loginInvalidCredentials;

  /// No description provided for @loginAccountPending.
  ///
  /// In en, this message translates to:
  /// **'Your account is still under review.'**
  String get loginAccountPending;

  /// No description provided for @loginAccountRejected.
  ///
  /// In en, this message translates to:
  /// **'Your account was rejected: {reason}'**
  String loginAccountRejected(Object reason);

  /// No description provided for @loginWrongRole.
  ///
  /// In en, this message translates to:
  /// **'No {role} account found for this number.'**
  String loginWrongRole(Object role);

  /// No description provided for @loginLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get loginLogoutConfirm;

  /// No description provided for @driverStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get driverStatus;

  /// No description provided for @driverStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get driverStatusPending;

  /// No description provided for @driverStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get driverStatusApproved;

  /// No description provided for @driverStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get driverStatusRejected;

  /// No description provided for @driverPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get driverPendingApproval;

  /// No description provided for @driverPendingNote.
  ///
  /// In en, this message translates to:
  /// **'Your documents are being verified by our team. This usually takes 24-48 hours.'**
  String get driverPendingNote;

  /// No description provided for @driverVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get driverVerifiedBadge;

  /// No description provided for @driverVerifiedDriver.
  ///
  /// In en, this message translates to:
  /// **'Verified Driver'**
  String get driverVerifiedDriver;

  /// No description provided for @driverUnverified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get driverUnverified;

  /// No description provided for @driverRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason: {reason}'**
  String driverRejectionReason(Object reason);

  /// No description provided for @driverOnlineRestricted.
  ///
  /// In en, this message translates to:
  /// **'You can only go online after your application is approved.'**
  String get driverOnlineRestricted;

  /// No description provided for @driverVerificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Verification Status'**
  String get driverVerificationStatus;

  /// No description provided for @driverDocumentsApproved.
  ///
  /// In en, this message translates to:
  /// **'Documents Approved'**
  String get driverDocumentsApproved;

  /// No description provided for @regTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a Driver'**
  String get regTitle;

  /// No description provided for @regSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn on your own schedule'**
  String get regSubtitle;

  /// No description provided for @regStep1.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get regStep1;

  /// No description provided for @regStep2.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get regStep2;

  /// No description provided for @regStep3.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get regStep3;

  /// No description provided for @regStep4.
  ///
  /// In en, this message translates to:
  /// **'Association'**
  String get regStep4;

  /// No description provided for @regStep5.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get regStep5;

  /// No description provided for @regFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get regFullName;

  /// No description provided for @regFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'John Dela Cruz'**
  String get regFullNameHint;

  /// No description provided for @regMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get regMobileNumber;

  /// No description provided for @regMobileHint.
  ///
  /// In en, this message translates to:
  /// **'+63 912 345 6789'**
  String get regMobileHint;

  /// No description provided for @regPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get regPassword;

  /// No description provided for @regPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get regPasswordHint;

  /// No description provided for @regDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get regDateOfBirth;

  /// No description provided for @regSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get regSex;

  /// No description provided for @regMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get regMale;

  /// No description provided for @regFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get regFemale;

  /// No description provided for @regAddress.
  ///
  /// In en, this message translates to:
  /// **'Current Address'**
  String get regAddress;

  /// No description provided for @regAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Block, Lot, Street, Barangay, City...'**
  String get regAddressHint;

  /// No description provided for @regLicenseType.
  ///
  /// In en, this message translates to:
  /// **'License Type'**
  String get regLicenseType;

  /// No description provided for @regNonProfessional.
  ///
  /// In en, this message translates to:
  /// **'Non-Professional'**
  String get regNonProfessional;

  /// No description provided for @regProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get regProfessional;

  /// No description provided for @regLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'License Number'**
  String get regLicenseNumber;

  /// No description provided for @regLicenseNumberHint.
  ///
  /// In en, this message translates to:
  /// **'N01-12-345678'**
  String get regLicenseNumberHint;

  /// No description provided for @regLicenseExpiry.
  ///
  /// In en, this message translates to:
  /// **'License Expiry Date'**
  String get regLicenseExpiry;

  /// No description provided for @regDlCodes.
  ///
  /// In en, this message translates to:
  /// **'DL Codes'**
  String get regDlCodes;

  /// No description provided for @regConditionCodes.
  ///
  /// In en, this message translates to:
  /// **'Condition Codes'**
  String get regConditionCodes;

  /// No description provided for @regVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get regVehicleType;

  /// No description provided for @regPlateNumber.
  ///
  /// In en, this message translates to:
  /// **'Plate Number'**
  String get regPlateNumber;

  /// No description provided for @regMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get regMake;

  /// No description provided for @regModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get regModel;

  /// No description provided for @regYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get regYear;

  /// No description provided for @regColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get regColor;

  /// No description provided for @regToda.
  ///
  /// In en, this message translates to:
  /// **'TODA Association'**
  String get regToda;

  /// No description provided for @regTodaHint.
  ///
  /// In en, this message translates to:
  /// **'Select your TODA'**
  String get regTodaHint;

  /// No description provided for @regTodaNotListed.
  ///
  /// In en, this message translates to:
  /// **'My TODA is not listed'**
  String get regTodaNotListed;

  /// No description provided for @regBarangay.
  ///
  /// In en, this message translates to:
  /// **'Barangay'**
  String get regBarangay;

  /// No description provided for @regMunicipality.
  ///
  /// In en, this message translates to:
  /// **'Municipality'**
  String get regMunicipality;

  /// No description provided for @regProvince.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get regProvince;

  /// No description provided for @regDocLicenseFront.
  ///
  /// In en, this message translates to:
  /// **'License Photo (Front)'**
  String get regDocLicenseFront;

  /// No description provided for @regDocLicenseBack.
  ///
  /// In en, this message translates to:
  /// **'License Photo (Back)'**
  String get regDocLicenseBack;

  /// No description provided for @regDocOrCr.
  ///
  /// In en, this message translates to:
  /// **'OR/CR Photo'**
  String get regDocOrCr;

  /// No description provided for @regDocProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get regDocProfile;

  /// No description provided for @regUploadTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload'**
  String get regUploadTap;

  /// No description provided for @regUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get regUploaded;

  /// No description provided for @regSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get regSubmitApplication;

  /// No description provided for @regNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next: {step}'**
  String regNextStep(Object step);

  /// No description provided for @regPrevStep.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get regPrevStep;

  /// No description provided for @regApplicationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application Submitted!'**
  String get regApplicationSubmitted;

  /// No description provided for @regApplicationSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your application is now pending review. We will notify you once your account is verified.'**
  String get regApplicationSubmittedBody;

  /// No description provided for @regBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get regBackToLogin;

  /// No description provided for @regFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get regFillRequired;

  /// No description provided for @regPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get regPasswordTooShort;

  /// No description provided for @regUploadAllDocs.
  ///
  /// In en, this message translates to:
  /// **'Please upload all required documents.'**
  String get regUploadAllDocs;

  /// No description provided for @regSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome aboard!'**
  String get regSuccessTitle;

  /// No description provided for @regSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your application has been received. An admin will review your documents within 24-48 hours.'**
  String get regSuccessBody;

  /// No description provided for @vehicleTricycle.
  ///
  /// In en, this message translates to:
  /// **'Tricycle'**
  String get vehicleTricycle;

  /// No description provided for @vehicleHabal.
  ///
  /// In en, this message translates to:
  /// **'Habal-Habal'**
  String get vehicleHabal;

  /// No description provided for @vehicleTricycleSub.
  ///
  /// In en, this message translates to:
  /// **'3-4 pax'**
  String get vehicleTricycleSub;

  /// No description provided for @vehicleHabalSub.
  ///
  /// In en, this message translates to:
  /// **'1-2 pax'**
  String get vehicleHabalSub;

  /// No description provided for @vehicleStartsAt.
  ///
  /// In en, this message translates to:
  /// **'Starts at'**
  String get vehicleStartsAt;

  /// No description provided for @vehicleMinsAway.
  ///
  /// In en, this message translates to:
  /// **'mins away'**
  String get vehicleMinsAway;

  /// No description provided for @vehicleAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} available nearby'**
  String vehicleAvailable(Object count);

  /// No description provided for @vehicleChooseType.
  ///
  /// In en, this message translates to:
  /// **'Choose your ride'**
  String get vehicleChooseType;

  /// No description provided for @vehicleBaseFare.
  ///
  /// In en, this message translates to:
  /// **'Base Fare'**
  String get vehicleBaseFare;

  /// No description provided for @vehiclePerKm.
  ///
  /// In en, this message translates to:
  /// **'Per km'**
  String get vehiclePerKm;

  /// No description provided for @bookingPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get bookingPickup;

  /// No description provided for @bookingDropoff.
  ///
  /// In en, this message translates to:
  /// **'Drop-off location'**
  String get bookingDropoff;

  /// No description provided for @bookingEnterPickup.
  ///
  /// In en, this message translates to:
  /// **'Enter pickup location'**
  String get bookingEnterPickup;

  /// No description provided for @bookingEnterDropoff.
  ///
  /// In en, this message translates to:
  /// **'Enter destination'**
  String get bookingEnterDropoff;

  /// No description provided for @bookingUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get bookingUseCurrentLocation;

  /// No description provided for @bookingSearchingDrivers.
  ///
  /// In en, this message translates to:
  /// **'Searching for drivers...'**
  String get bookingSearchingDrivers;

  /// No description provided for @bookingSearchingBody.
  ///
  /// In en, this message translates to:
  /// **'We are finding the nearest {vehicle} for you.'**
  String bookingSearchingBody(Object vehicle);

  /// No description provided for @bookingCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get bookingCancelBooking;

  /// No description provided for @bookingCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this ride request?'**
  String get bookingCancelConfirm;

  /// No description provided for @bookingEstimatedFare.
  ///
  /// In en, this message translates to:
  /// **'Estimated Fare'**
  String get bookingEstimatedFare;

  /// No description provided for @bookingEstimatedDistance.
  ///
  /// In en, this message translates to:
  /// **'Estimated distance'**
  String get bookingEstimatedDistance;

  /// No description provided for @bookingEstimatedDuration.
  ///
  /// In en, this message translates to:
  /// **'Estimated travel time'**
  String get bookingEstimatedDuration;

  /// No description provided for @bookingBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookingBookNow;

  /// No description provided for @bookingRequestRide.
  ///
  /// In en, this message translates to:
  /// **'Request Ride'**
  String get bookingRequestRide;

  /// No description provided for @bookingChooseVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select Vehicle'**
  String get bookingChooseVehicle;

  /// No description provided for @bookingSelectPayment.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get bookingSelectPayment;

  /// No description provided for @bookingPaymentNote.
  ///
  /// In en, this message translates to:
  /// **'You can pay with cash or any digital wallet.'**
  String get bookingPaymentNote;

  /// No description provided for @bookingLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Please set your pickup and destination.'**
  String get bookingLocationRequired;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Ride booked successfully'**
  String get bookingConfirmed;

  /// No description provided for @bookingRequestQueued.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Your ride request is queued and will be sent when you reconnect.'**
  String get bookingRequestQueued;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentGcash.
  ///
  /// In en, this message translates to:
  /// **'GCash'**
  String get paymentGcash;

  /// No description provided for @paymentMaya.
  ///
  /// In en, this message translates to:
  /// **'PayMaya'**
  String get paymentMaya;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Credit / Debit Card'**
  String get paymentCard;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @paymentPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get paymentPayNow;

  /// No description provided for @paymentPayFare.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String paymentPayFare(Object amount);

  /// No description provided for @paymentAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add New Card'**
  String get paymentAddCard;

  /// No description provided for @paymentCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get paymentCardNumber;

  /// No description provided for @paymentCardHolder.
  ///
  /// In en, this message translates to:
  /// **'Cardholder Name'**
  String get paymentCardHolder;

  /// No description provided for @paymentExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get paymentExpiry;

  /// No description provided for @paymentCvv.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get paymentCvv;

  /// No description provided for @paymentCardAdded.
  ///
  /// In en, this message translates to:
  /// **'Card added successfully'**
  String get paymentCardAdded;

  /// No description provided for @paymentGcashConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will be redirected to GCash to complete the payment.'**
  String get paymentGcashConfirm;

  /// No description provided for @paymentMayaConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will be redirected to PayMaya to complete the payment.'**
  String get paymentMayaConfirm;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get paymentSuccess;

  /// No description provided for @paymentSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment of {amount} was processed. Thank you for riding with Sakay Ta!'**
  String paymentSuccessBody(Object amount);

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @paymentFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Please check your payment method and try again.'**
  String get paymentFailedBody;

  /// No description provided for @paymentChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose payment method'**
  String get paymentChoose;

  /// No description provided for @paymentDriverConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Driver payment confirmation'**
  String get paymentDriverConfirmation;

  /// No description provided for @paymentReceivedCash.
  ///
  /// In en, this message translates to:
  /// **'Driver confirmed receipt of ₱{amount} cash.'**
  String paymentReceivedCash(Object amount);

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @paymentPaidVia.
  ///
  /// In en, this message translates to:
  /// **'Paid via {method}'**
  String paymentPaidVia(Object method);

  /// No description provided for @paymentReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Digital Receipt'**
  String get paymentReceiptTitle;

  /// No description provided for @paymentReceiptNo.
  ///
  /// In en, this message translates to:
  /// **'Receipt No.'**
  String get paymentReceiptNo;

  /// No description provided for @paymentTripDate.
  ///
  /// In en, this message translates to:
  /// **'Trip Date'**
  String get paymentTripDate;

  /// No description provided for @paymentFareCharged.
  ///
  /// In en, this message translates to:
  /// **'Fare Charged'**
  String get paymentFareCharged;

  /// No description provided for @paymentTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get paymentTotalPaid;

  /// No description provided for @paymentThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for riding Sakay Ta!'**
  String get paymentThankYou;

  /// No description provided for @paymentReceiptSent.
  ///
  /// In en, this message translates to:
  /// **'Receipt sent to your email'**
  String get paymentReceiptSent;

  /// No description provided for @trackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Tracking'**
  String get trackingTitle;

  /// No description provided for @trackingSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for your driver...'**
  String get trackingSearching;

  /// No description provided for @trackingAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver found!'**
  String get trackingAccepted;

  /// No description provided for @trackingAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'{driver} is heading to your pickup.'**
  String trackingAcceptedBody(Object driver);

  /// No description provided for @trackingArrived.
  ///
  /// In en, this message translates to:
  /// **'Your driver has arrived'**
  String get trackingArrived;

  /// No description provided for @trackingStarted.
  ///
  /// In en, this message translates to:
  /// **'On the way to your destination'**
  String get trackingStarted;

  /// No description provided for @trackingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get trackingCompleted;

  /// No description provided for @trackingDriverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Your driver is on the way'**
  String get trackingDriverOnTheWay;

  /// No description provided for @trackingEta.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get trackingEta;

  /// No description provided for @trackingMinsAway.
  ///
  /// In en, this message translates to:
  /// **'MINS AWAY'**
  String get trackingMinsAway;

  /// No description provided for @trackingDriverInfo.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get trackingDriverInfo;

  /// No description provided for @trackingPlateNumber.
  ///
  /// In en, this message translates to:
  /// **'Plate Number'**
  String get trackingPlateNumber;

  /// No description provided for @trackingRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get trackingRating;

  /// No description provided for @trackingMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get trackingMessage;

  /// No description provided for @trackingCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get trackingCall;

  /// No description provided for @trackingMaskedCall.
  ///
  /// In en, this message translates to:
  /// **'Masked call'**
  String get trackingMaskedCall;

  /// No description provided for @trackingShareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share Trip Details'**
  String get trackingShareTrip;

  /// No description provided for @trackingShareBody.
  ///
  /// In en, this message translates to:
  /// **'I\'m riding with Sakay Ta! {vehicle} · {plate} · {driver} · ETA {eta} mins. Track me live in the app.'**
  String trackingShareBody(
      Object driver, Object eta, Object plate, Object vehicle);

  /// No description provided for @trackingEndTrip.
  ///
  /// In en, this message translates to:
  /// **'End Trip'**
  String get trackingEndTrip;

  /// No description provided for @trackingStartRide.
  ///
  /// In en, this message translates to:
  /// **'Start Ride'**
  String get trackingStartRide;

  /// No description provided for @trackingMarkArrived.
  ///
  /// In en, this message translates to:
  /// **'I\'ve Arrived'**
  String get trackingMarkArrived;

  /// No description provided for @trackingPickup.
  ///
  /// In en, this message translates to:
  /// **'PICKUP'**
  String get trackingPickup;

  /// No description provided for @trackingDropoff.
  ///
  /// In en, this message translates to:
  /// **'DROPOFF'**
  String get trackingDropoff;

  /// No description provided for @trackingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get trackingYourLocation;

  /// No description provided for @trackingShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Sakay Ta — Live Trip'**
  String get trackingShareTitle;

  /// No description provided for @trackingStatusSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get trackingStatusSearching;

  /// No description provided for @trackingStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get trackingStatusAccepted;

  /// No description provided for @trackingStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get trackingStatusArrived;

  /// No description provided for @trackingStatusStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get trackingStatusStarted;

  /// No description provided for @trackingStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get trackingStatusCompleted;

  /// No description provided for @trackingChatWithDriver.
  ///
  /// In en, this message translates to:
  /// **'Chat with {driver}'**
  String trackingChatWithDriver(Object driver);

  /// No description provided for @trackingChatHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get trackingChatHint;

  /// No description provided for @trackingNoChats.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hi to your driver!'**
  String get trackingNoChats;

  /// No description provided for @trackingRateDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate your driver'**
  String get trackingRateDriver;

  /// No description provided for @trackingRateTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your ride?'**
  String get trackingRateTitle;

  /// No description provided for @trackingRateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get trackingRateSubmit;

  /// No description provided for @trackingThanksFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get trackingThanksFeedback;

  /// No description provided for @trackingCancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel Ride'**
  String get trackingCancelRide;

  /// No description provided for @trackingRideCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get trackingRideCancelled;

  /// No description provided for @ridesUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get ridesUpcoming;

  /// No description provided for @ridesHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get ridesHistory;

  /// No description provided for @ridesNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming rides'**
  String get ridesNoUpcoming;

  /// No description provided for @ridesNoUpcomingBody.
  ///
  /// In en, this message translates to:
  /// **'Ready to go? Book a ride to see it here.'**
  String get ridesNoUpcomingBody;

  /// No description provided for @ridesNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get ridesNoHistory;

  /// No description provided for @ridesNoHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Your completed trips will appear here.'**
  String get ridesNoHistoryBody;

  /// No description provided for @ridesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get ridesCompleted;

  /// No description provided for @ridesCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ridesCancelled;

  /// No description provided for @ridesViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get ridesViewDetails;

  /// No description provided for @ridesRideHistory.
  ///
  /// In en, this message translates to:
  /// **'Ride History'**
  String get ridesRideHistory;

  /// No description provided for @ridesRebook.
  ///
  /// In en, this message translates to:
  /// **'Rebook'**
  String get ridesRebook;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// No description provided for @profilePaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get profilePaymentMethods;

  /// No description provided for @profileSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved Places'**
  String get profileSavedPlaces;

  /// No description provided for @profileSavedPlacesDetail.
  ///
  /// In en, this message translates to:
  /// **'Home, Work'**
  String get profileSavedPlacesDetail;

  /// No description provided for @profilePreferencesSupport.
  ///
  /// In en, this message translates to:
  /// **'Preferences & Support'**
  String get profilePreferencesSupport;

  /// No description provided for @profileHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get profileHelpCenter;

  /// No description provided for @profileAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get profileAccountSettings;

  /// No description provided for @profileHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get profileHistory;

  /// No description provided for @profileTrustedPassenger.
  ///
  /// In en, this message translates to:
  /// **'Trusted Passenger'**
  String get profileTrustedPassenger;

  /// No description provided for @profileVerifiedPassenger.
  ///
  /// In en, this message translates to:
  /// **'Verified Passenger'**
  String get profileVerifiedPassenger;

  /// No description provided for @profileLanguageDetail.
  ///
  /// In en, this message translates to:
  /// **'Language Preference'**
  String get profileLanguageDetail;

  /// No description provided for @profileLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get profileLanguageLabel;

  /// No description provided for @profileDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get profileDarkMode;

  /// No description provided for @profileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About Sakay Ta'**
  String get profileAbout;

  /// No description provided for @profileVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get profileVersion;

  /// No description provided for @profileTotalRides.
  ///
  /// In en, this message translates to:
  /// **'Total Rides'**
  String get profileTotalRides;

  /// No description provided for @profileJoinedSince.
  ///
  /// In en, this message translates to:
  /// **'Joined Since'**
  String get profileJoinedSince;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profilePersonalInfo;

  /// No description provided for @profileFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get profileFullName;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get profileMobile;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'TOTAL AVAILABLE BALANCE'**
  String get walletTotalBalance;

  /// No description provided for @walletCashEarnings.
  ///
  /// In en, this message translates to:
  /// **'Cash Earnings'**
  String get walletCashEarnings;

  /// No description provided for @walletDigitalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Digital (e-wallet)'**
  String get walletDigitalEarnings;

  /// No description provided for @walletWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get walletWithdraw;

  /// No description provided for @walletRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get walletRecentTransactions;

  /// No description provided for @walletTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get walletTransactionHistory;

  /// No description provided for @walletWithdrawTo.
  ///
  /// In en, this message translates to:
  /// **'Withdraw To'**
  String get walletWithdrawTo;

  /// No description provided for @walletGcash.
  ///
  /// In en, this message translates to:
  /// **'GCash'**
  String get walletGcash;

  /// No description provided for @walletBank.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get walletBank;

  /// No description provided for @walletEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get walletEnterAmount;

  /// No description provided for @walletMinMax.
  ///
  /// In en, this message translates to:
  /// **'Min ₱100 · Max ₱50,000 per transaction'**
  String get walletMinMax;

  /// No description provided for @walletWithdrawAmount.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal Amount'**
  String get walletWithdrawAmount;

  /// No description provided for @walletProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing your withdrawal...'**
  String get walletProcessing;

  /// No description provided for @walletSuccess.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal Successful'**
  String get walletSuccess;

  /// No description provided for @walletSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'₱{amount} has been sent to your {method} account.'**
  String walletSuccessBody(Object amount, Object method);

  /// No description provided for @walletInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance.'**
  String get walletInsufficient;

  /// No description provided for @walletInsufficientBody.
  ///
  /// In en, this message translates to:
  /// **'Your available balance is only ₱{amount}.'**
  String walletInsufficientBody(Object amount);

  /// No description provided for @walletNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get walletNoHistory;

  /// No description provided for @walletFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get walletFilterAll;

  /// No description provided for @walletFilterIncoming.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get walletFilterIncoming;

  /// No description provided for @walletFilterWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals'**
  String get walletFilterWithdrawal;

  /// No description provided for @walletDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get walletDaily;

  /// No description provided for @walletWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get walletWeekly;

  /// No description provided for @walletMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get walletMonthly;

  /// No description provided for @earningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earningsTitle;

  /// No description provided for @earningsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get earningsToday;

  /// No description provided for @earningsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get earningsThisWeek;

  /// No description provided for @earningsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get earningsThisMonth;

  /// No description provided for @earningsTotalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get earningsTotalEarnings;

  /// No description provided for @earningsNetEarnings.
  ///
  /// In en, this message translates to:
  /// **'Ride Earnings'**
  String get earningsNetEarnings;

  /// No description provided for @earningsCommission.
  ///
  /// In en, this message translates to:
  /// **'Fare Earnings'**
  String get earningsCommission;

  /// No description provided for @earningsFare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get earningsFare;

  /// No description provided for @earningsTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get earningsTrips;

  /// No description provided for @earningsHoursOnline.
  ///
  /// In en, this message translates to:
  /// **'Hours Online'**
  String get earningsHoursOnline;

  /// No description provided for @earningsTripsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} trips'**
  String earningsTripsCount(Object count);

  /// No description provided for @earningsTripsAndHours.
  ///
  /// In en, this message translates to:
  /// **'{trips} trips · {hours} hours'**
  String earningsTripsAndHours(Object hours, Object trips);

  /// No description provided for @earningsTodayEarnings.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Earnings'**
  String get earningsTodayEarnings;

  /// No description provided for @earningsUpFromYesterday.
  ///
  /// In en, this message translates to:
  /// **'+{pct}% from yesterday'**
  String earningsUpFromYesterday(Object pct);

  /// No description provided for @earningsDownFromYesterday.
  ///
  /// In en, this message translates to:
  /// **'{pct}% from yesterday'**
  String earningsDownFromYesterday(Object pct);

  /// No description provided for @earningsWeeklySummary.
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get earningsWeeklySummary;

  /// No description provided for @earningsDailyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Daily breakdown'**
  String get earningsDailyBreakdown;

  /// No description provided for @earningsNoEarnings.
  ///
  /// In en, this message translates to:
  /// **'No earnings yet this period'**
  String get earningsNoEarnings;

  /// No description provided for @earningsLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Earnings'**
  String get earningsLifetime;

  /// No description provided for @earningsCompletedTrips.
  ///
  /// In en, this message translates to:
  /// **'Completed Trips'**
  String get earningsCompletedTrips;

  /// No description provided for @performanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performanceTitle;

  /// No description provided for @performanceStats.
  ///
  /// In en, this message translates to:
  /// **'Performance Stats'**
  String get performanceStats;

  /// No description provided for @performanceYourPerformance.
  ///
  /// In en, this message translates to:
  /// **'Your Performance'**
  String get performanceYourPerformance;

  /// No description provided for @performanceRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get performanceRating;

  /// No description provided for @performanceAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Acceptance'**
  String get performanceAcceptance;

  /// No description provided for @performanceAcceptanceRate.
  ///
  /// In en, this message translates to:
  /// **'Acceptance Rate'**
  String get performanceAcceptanceRate;

  /// No description provided for @performanceAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get performanceAccuracy;

  /// No description provided for @performanceAccuracyRate.
  ///
  /// In en, this message translates to:
  /// **'On-time Arrival'**
  String get performanceAccuracyRate;

  /// No description provided for @performanceCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation'**
  String get performanceCancellation;

  /// No description provided for @performanceTotalTrips.
  ///
  /// In en, this message translates to:
  /// **'Total Trips'**
  String get performanceTotalTrips;

  /// No description provided for @performanceLifetimeEarnings.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Earnings'**
  String get performanceLifetimeEarnings;

  /// No description provided for @performanceWeeklyComparison.
  ///
  /// In en, this message translates to:
  /// **'Weekly Comparison'**
  String get performanceWeeklyComparison;

  /// No description provided for @performanceLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last Week'**
  String get performanceLastWeek;

  /// No description provided for @performanceCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get performanceCurrentWeek;

  /// No description provided for @performanceTripsEarnings.
  ///
  /// In en, this message translates to:
  /// **'Trips & Earnings'**
  String get performanceTripsEarnings;

  /// No description provided for @performanceFeedback.
  ///
  /// In en, this message translates to:
  /// **'Passenger Feedback'**
  String get performanceFeedback;

  /// No description provided for @performanceSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get performanceSeeAll;

  /// No description provided for @performanceTopTier.
  ///
  /// In en, this message translates to:
  /// **'Top Tier'**
  String get performanceTopTier;

  /// No description provided for @performanceAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get performanceAverage;

  /// No description provided for @performanceExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get performanceExcellent;

  /// No description provided for @performanceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get performanceLow;

  /// No description provided for @performanceBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges & Achievements'**
  String get performanceBadges;

  /// No description provided for @performanceAchievement1.
  ///
  /// In en, this message translates to:
  /// **'Road Warrior'**
  String get performanceAchievement1;

  /// No description provided for @performanceAchievement1Desc.
  ///
  /// In en, this message translates to:
  /// **'100 trips completed'**
  String get performanceAchievement1Desc;

  /// No description provided for @performanceAchievement2.
  ///
  /// In en, this message translates to:
  /// **'Early Bird'**
  String get performanceAchievement2;

  /// No description provided for @performanceAchievement2Desc.
  ///
  /// In en, this message translates to:
  /// **'First trip before 7 AM'**
  String get performanceAchievement2Desc;

  /// No description provided for @performanceAchievement3.
  ///
  /// In en, this message translates to:
  /// **'Star Rider'**
  String get performanceAchievement3;

  /// No description provided for @performanceAchievement3Desc.
  ///
  /// In en, this message translates to:
  /// **'5.0 average rating'**
  String get performanceAchievement3Desc;

  /// No description provided for @performanceAchievement4.
  ///
  /// In en, this message translates to:
  /// **'Weekend Hero'**
  String get performanceAchievement4;

  /// No description provided for @performanceAchievement4Desc.
  ///
  /// In en, this message translates to:
  /// **'20 trips in one weekend'**
  String get performanceAchievement4Desc;

  /// No description provided for @performanceAchievement5.
  ///
  /// In en, this message translates to:
  /// **'Safe Driver'**
  String get performanceAchievement5;

  /// No description provided for @performanceAchievement5Desc.
  ///
  /// In en, this message translates to:
  /// **'100 trips with zero complaints'**
  String get performanceAchievement5Desc;

  /// No description provided for @performanceLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get performanceLocked;

  /// No description provided for @performanceTierLabel.
  ///
  /// In en, this message translates to:
  /// **'Tier: {tier}'**
  String performanceTierLabel(Object tier);

  /// No description provided for @performanceLguCompliance.
  ///
  /// In en, this message translates to:
  /// **'LGU Compliance'**
  String get performanceLguCompliance;

  /// No description provided for @performanceLguActive.
  ///
  /// In en, this message translates to:
  /// **'Active & verified'**
  String get performanceLguActive;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminTitle;

  /// No description provided for @adminDrivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get adminDrivers;

  /// No description provided for @adminPassengers.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get adminPassengers;

  /// No description provided for @adminTotalTrips.
  ///
  /// In en, this message translates to:
  /// **'Total Trips'**
  String get adminTotalTrips;

  /// No description provided for @adminTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Platform Revenue'**
  String get adminTotalRevenue;

  /// No description provided for @adminPendingReviews.
  ///
  /// In en, this message translates to:
  /// **'Pending Reviews'**
  String get adminPendingReviews;

  /// No description provided for @adminApprovedDrivers.
  ///
  /// In en, this message translates to:
  /// **'Approved Drivers'**
  String get adminApprovedDrivers;

  /// No description provided for @adminRejectedDrivers.
  ///
  /// In en, this message translates to:
  /// **'Rejected Drivers'**
  String get adminRejectedDrivers;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection (optional)'**
  String get adminRejectReason;

  /// No description provided for @adminRejectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Reject this driver? They will be notified with your reason.'**
  String get adminRejectPrompt;

  /// No description provided for @adminApprovePrompt.
  ///
  /// In en, this message translates to:
  /// **'Approve this driver? They will be able to go online immediately.'**
  String get adminApprovePrompt;

  /// No description provided for @adminDriverApproved.
  ///
  /// In en, this message translates to:
  /// **'Driver approved'**
  String get adminDriverApproved;

  /// No description provided for @adminDriverRejected.
  ///
  /// In en, this message translates to:
  /// **'Driver rejected'**
  String get adminDriverRejected;

  /// No description provided for @adminViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get adminViewDetails;

  /// No description provided for @adminManageDrivers.
  ///
  /// In en, this message translates to:
  /// **'Manage Drivers'**
  String get adminManageDrivers;

  /// No description provided for @adminDriverId.
  ///
  /// In en, this message translates to:
  /// **'Driver ID'**
  String get adminDriverId;

  /// No description provided for @adminSubmittedAt.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get adminSubmittedAt;

  /// No description provided for @adminTodaReports.
  ///
  /// In en, this message translates to:
  /// **'TODA Reports'**
  String get adminTodaReports;

  /// No description provided for @adminTodaTitle.
  ///
  /// In en, this message translates to:
  /// **'TODA Management'**
  String get adminTodaTitle;

  /// No description provided for @adminAddToda.
  ///
  /// In en, this message translates to:
  /// **'Add TODA'**
  String get adminAddToda;

  /// No description provided for @adminEditToda.
  ///
  /// In en, this message translates to:
  /// **'Edit TODA'**
  String get adminEditToda;

  /// No description provided for @adminDeleteToda.
  ///
  /// In en, this message translates to:
  /// **'Delete TODA'**
  String get adminDeleteToda;

  /// No description provided for @adminTodaName.
  ///
  /// In en, this message translates to:
  /// **'TODA Name'**
  String get adminTodaName;

  /// No description provided for @adminTodaLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader Name'**
  String get adminTodaLeader;

  /// No description provided for @adminTodaContact.
  ///
  /// In en, this message translates to:
  /// **'Contact Number'**
  String get adminTodaContact;

  /// No description provided for @adminTodaArea.
  ///
  /// In en, this message translates to:
  /// **'Service Area'**
  String get adminTodaArea;

  /// No description provided for @adminTodaMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get adminTodaMembers;

  /// No description provided for @adminDeleteTodaConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this TODA?'**
  String get adminDeleteTodaConfirm;

  /// No description provided for @adminTodaAdded.
  ///
  /// In en, this message translates to:
  /// **'TODA added'**
  String get adminTodaAdded;

  /// No description provided for @adminTodaUpdated.
  ///
  /// In en, this message translates to:
  /// **'TODA updated'**
  String get adminTodaUpdated;

  /// No description provided for @adminTodaDeleted.
  ///
  /// In en, this message translates to:
  /// **'TODA deleted'**
  String get adminTodaDeleted;

  /// No description provided for @adminLguPartnerships.
  ///
  /// In en, this message translates to:
  /// **'LGU Partnerships'**
  String get adminLguPartnerships;

  /// No description provided for @adminAddPartnership.
  ///
  /// In en, this message translates to:
  /// **'Add Partnership'**
  String get adminAddPartnership;

  /// No description provided for @adminPartnershipName.
  ///
  /// In en, this message translates to:
  /// **'LGU / Municipality'**
  String get adminPartnershipName;

  /// No description provided for @adminPartnershipActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminPartnershipActive;

  /// No description provided for @adminPartnershipInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminPartnershipInactive;

  /// No description provided for @adminReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReports;

  /// No description provided for @adminReportsByToda.
  ///
  /// In en, this message translates to:
  /// **'Reports by TODA'**
  String get adminReportsByToda;

  /// No description provided for @adminDriverCount.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get adminDriverCount;

  /// No description provided for @adminTripCount.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get adminTripCount;

  /// No description provided for @adminRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get adminRevenue;

  /// No description provided for @adminAvgRating.
  ///
  /// In en, this message translates to:
  /// **'Avg Rating'**
  String get adminAvgRating;

  /// No description provided for @adminExport.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get adminExport;

  /// No description provided for @adminExported.
  ///
  /// In en, this message translates to:
  /// **'Report exported'**
  String get adminExported;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get offlineTitle;

  /// No description provided for @offlineBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re currently offline. Showing cached data.'**
  String get offlineBody;

  /// No description provided for @offlineReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get offlineReconnecting;

  /// No description provided for @offlineBackOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get offlineBackOnline;

  /// No description provided for @offlineQueuedRequests.
  ///
  /// In en, this message translates to:
  /// **'Queued requests: {count}'**
  String offlineQueuedRequests(Object count);

  /// No description provided for @offlineSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing your queued requests...'**
  String get offlineSyncing;

  /// No description provided for @offlineSynced.
  ///
  /// In en, this message translates to:
  /// **'All queued requests synced'**
  String get offlineSynced;

  /// No description provided for @offlineCached.
  ///
  /// In en, this message translates to:
  /// **'Cached data'**
  String get offlineCached;

  /// No description provided for @offlineWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection...'**
  String get offlineWaiting;

  /// No description provided for @mapLabel.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapLabel;

  /// No description provided for @mapOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'Showing cached map tiles'**
  String get mapOfflineNotice;

  /// No description provided for @notifRideRequest.
  ///
  /// In en, this message translates to:
  /// **'New ride request'**
  String get notifRideRequest;

  /// No description provided for @notifPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get notifPaymentReceived;

  /// No description provided for @notifAccountApproved.
  ///
  /// In en, this message translates to:
  /// **'Your account has been approved!'**
  String get notifAccountApproved;

  /// No description provided for @notifAccountRejected.
  ///
  /// In en, this message translates to:
  /// **'Your account was rejected'**
  String get notifAccountRejected;

  /// No description provided for @notifDriverArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get notifDriverArrived;

  /// No description provided for @notifTripCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get notifTripCompleted;

  /// No description provided for @notifChat.
  ///
  /// In en, this message translates to:
  /// **'New message from {name}'**
  String notifChat(Object name);

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatYou;

  /// No description provided for @chatDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get chatDriver;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatTypeMessage;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoMessages;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @langCeb.
  ///
  /// In en, this message translates to:
  /// **'Cebuano'**
  String get langCeb;

  /// No description provided for @langTl.
  ///
  /// In en, this message translates to:
  /// **'Tagalog'**
  String get langTl;

  /// No description provided for @langAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get langAppLanguage;

  /// No description provided for @langChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed'**
  String get langChanged;

  /// No description provided for @signUpPassengerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Up as Passenger'**
  String get signUpPassengerTitle;

  /// No description provided for @signUpPassengerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up to start booking your rides safely and easily.'**
  String get signUpPassengerSubtitle;

  /// No description provided for @signUpFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get signUpFullName;

  /// No description provided for @signUpFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Juan Dela Cruz'**
  String get signUpFullNameHint;

  /// No description provided for @signUpFullNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name (at least 2 characters).'**
  String get signUpFullNameError;

  /// No description provided for @signUpMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get signUpMobileNumber;

  /// No description provided for @signUpMobileHint.
  ///
  /// In en, this message translates to:
  /// **'09XX XXX XXXX'**
  String get signUpMobileHint;

  /// No description provided for @signUpMobileError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 11-digit Philippine mobile number.'**
  String get signUpMobileError;

  /// No description provided for @signUpPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signUpPassword;

  /// No description provided for @signUpPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get signUpPasswordHint;

  /// No description provided for @signUpPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get signUpPasswordError;

  /// No description provided for @signUpConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get signUpConfirmPassword;

  /// No description provided for @signUpConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get signUpConfirmPasswordHint;

  /// No description provided for @signUpConfirmPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get signUpConfirmPasswordError;

  /// No description provided for @signUpTermsText.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms and Conditions and Privacy Policy'**
  String get signUpTermsText;

  /// No description provided for @signUpTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the Terms and Conditions to proceed.'**
  String get signUpTermsRequired;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// No description provided for @signUpAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get signUpAlreadyHaveAccount;

  /// No description provided for @signUpLoginLink.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get signUpLoginLink;

  /// No description provided for @signUpPreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get signUpPreferredLanguage;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// No description provided for @navWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get navWallet;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @profileClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get profileClearCache;

  /// No description provided for @profileClearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free temporary files, map & weather cache'**
  String get profileClearCacheSubtitle;

  /// No description provided for @profileClearCacheSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully! ({size} freed)'**
  String profileClearCacheSuccess(Object size);

  /// No description provided for @profileClearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary cache? Your account and ride records will remain safe.'**
  String get profileClearCacheConfirm;

  /// No description provided for @profileLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogoutTitle;

  /// No description provided for @profileLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out on this device'**
  String get profileLogoutSubtitle;

  /// No description provided for @profileLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out? Your account and ride records are safely stored on the server.'**
  String get profileLogoutMessage;

  /// No description provided for @profileLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogoutButton;

  /// No description provided for @profileDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccountTitle;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently erase your account and server data'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @profileDeleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your Sakay Ta account? This action cannot be undone and will permanently remove your profile, ride history, and saved data from our servers.'**
  String get profileDeleteAccountWarning;

  /// No description provided for @profileDeleteAccountConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Permanently Delete'**
  String get profileDeleteAccountConfirmButton;

  /// No description provided for @profileDeleteAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted successfully.'**
  String get profileDeleteAccountSuccess;

  /// No description provided for @profileSelectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get profileSelectLanguage;

  /// No description provided for @profileBisayaLanguage.
  ///
  /// In en, this message translates to:
  /// **'Bisaya (Binisaya / Cebuano)'**
  String get profileBisayaLanguage;

  /// No description provided for @profileEnglishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English (US / PH)'**
  String get profileEnglishLanguage;

  /// No description provided for @profileTagalogLanguage.
  ///
  /// In en, this message translates to:
  /// **'Tagalog (Filipino)'**
  String get profileTagalogLanguage;

  /// No description provided for @profileDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get profileDangerZone;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning!'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon!'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening!'**
  String get homeGreetingEvening;

  /// No description provided for @homeWhereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get homeWhereTo;

  /// No description provided for @homeSearchDestination.
  ///
  /// In en, this message translates to:
  /// **'Search destination...'**
  String get homeSearchDestination;

  /// No description provided for @homeQuickDestinations.
  ///
  /// In en, this message translates to:
  /// **'Quick Destinations'**
  String get homeQuickDestinations;

  /// No description provided for @homeRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get homeRecentActivity;

  /// No description provided for @homeNearbyDrivers.
  ///
  /// In en, this message translates to:
  /// **'Nearby Drivers'**
  String get homeNearbyDrivers;

  /// No description provided for @homeNoNearbyDrivers.
  ///
  /// In en, this message translates to:
  /// **'No active drivers in your area right now.'**
  String get homeNoNearbyDrivers;

  /// No description provided for @homeBookRide.
  ///
  /// In en, this message translates to:
  /// **'Book a Ride'**
  String get homeBookRide;

  /// No description provided for @homeCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get homeCurrentLocation;

  /// No description provided for @homePopularPlaces.
  ///
  /// In en, this message translates to:
  /// **'Popular Places'**
  String get homePopularPlaces;

  /// No description provided for @walletCashIn.
  ///
  /// In en, this message translates to:
  /// **'Cash In / Top Up'**
  String get walletCashIn;

  /// No description provided for @walletSendMoney.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get walletSendMoney;

  /// No description provided for @walletAddPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get walletAddPaymentMethod;

  /// No description provided for @walletLinkedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get walletLinkedAccounts;

  /// No description provided for @walletDefaultPayment.
  ///
  /// In en, this message translates to:
  /// **'Default Payment'**
  String get walletDefaultPayment;

  /// No description provided for @walletManagePayments.
  ///
  /// In en, this message translates to:
  /// **'Manage Payment Methods'**
  String get walletManagePayments;

  /// No description provided for @walletSavedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Saved Payment Accounts'**
  String get walletSavedAccounts;

  /// No description provided for @walletHistoryReceipts.
  ///
  /// In en, this message translates to:
  /// **'Payment History & Receipts'**
  String get walletHistoryReceipts;

  /// No description provided for @walletNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No payment records yet.'**
  String get walletNoRecords;

  /// No description provided for @ridesEmptyUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming rides'**
  String get ridesEmptyUpcoming;

  /// No description provided for @ridesEmptyUpcomingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to go? Book a ride to see it here.'**
  String get ridesEmptyUpcomingSubtitle;

  /// No description provided for @ridesEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed trips yet'**
  String get ridesEmptyCompleted;

  /// No description provided for @ridesEmptyCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your ride receipts and completed trip history will appear here.'**
  String get ridesEmptyCompletedSubtitle;

  /// No description provided for @ridesEmptyCancelled.
  ///
  /// In en, this message translates to:
  /// **'No cancelled trips'**
  String get ridesEmptyCancelled;

  /// No description provided for @ridesEmptyCancelledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cancelled rides will appear here.'**
  String get ridesEmptyCancelledSubtitle;

  /// No description provided for @ridesBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book a Ride Now'**
  String get ridesBookNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ceb', 'en', 'tl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ceb':
      return AppLocalizationsCeb();
    case 'en':
      return AppLocalizationsEn();
    case 'tl':
      return AppLocalizationsTl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
