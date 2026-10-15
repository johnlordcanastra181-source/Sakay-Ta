// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tagalog (`tl`).
class AppLocalizationsTl extends AppLocalizations {
  AppLocalizationsTl([String locale = 'tl']) : super(locale);

  @override
  String get appName => 'Sakay Ta';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Kanselahin';

  @override
  String get commonSave => 'I-save';

  @override
  String get commonNext => 'Susunod';

  @override
  String get commonBack => 'Bumalik';

  @override
  String get commonContinue => 'Magpatuloy';

  @override
  String get commonSubmit => 'Isumite';

  @override
  String get commonSearch => 'Hanapin';

  @override
  String get commonDone => 'Tapos na';

  @override
  String get commonDelete => 'Tanggalin';

  @override
  String get commonEdit => 'I-edit';

  @override
  String get commonViewAll => 'Tingnan Lahat';

  @override
  String get commonAll => 'Lahat';

  @override
  String get commonClose => 'Isara';

  @override
  String get commonConfirm => 'Kumpirmahin';

  @override
  String get commonLogout => 'Mag-logout';

  @override
  String get commonLanguage => 'Wika';

  @override
  String get commonRetry => 'Subukan Muli';

  @override
  String get commonTryAgain => 'Subukan Muli';

  @override
  String get commonLoading => 'Naglo-load...';

  @override
  String get commonError => 'May nangyaring mali';

  @override
  String get commonNotAvailable => 'Hindi available';

  @override
  String get commonNoData => 'Walang datos';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOptional => '(opsyonal)';

  @override
  String get commonSkip => 'Laktawan';

  @override
  String get commonAdd => 'Idagdag';

  @override
  String get commonSelect => 'Pumili';

  @override
  String get commonUpload => 'I-upload';

  @override
  String get commonDetails => 'Mga Detalye';

  @override
  String get commonSettings => 'Mga Setting';

  @override
  String get commonEmpty => 'Wala pa dito';

  @override
  String get rolePassenger => 'Pasahero';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginGreeting => 'Magandang Umaga!';

  @override
  String get loginSubtitlePassenger => 'Mag-login para sumakay.';

  @override
  String get loginSubtitleDriver => 'Mag-login para kumita.';

  @override
  String get loginSubtitleAdmin => 'Mag-login para pamahalaan ang Sakay Ta.';

  @override
  String get loginMobileNumber => 'Numero ng Cellphone';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginMobileHint => '+63 9XX XXX XXXX';

  @override
  String get loginForgotPassword => 'Nakalimutan ang Password?';

  @override
  String get loginLoginButton => 'Mag-login';

  @override
  String get loginNoAccount => 'Wala pang account? Gumawa ngayon';

  @override
  String get loginLanguageLabel => 'Wika';

  @override
  String get loginDemoAccounts => 'Mga Demo Account';

  @override
  String get loginDemoPassenger => 'Pasaherong Demo';

  @override
  String get loginDemoDriver => 'Driver Demo';

  @override
  String get loginDemoAdmin => 'Admin Demo';

  @override
  String get loginPhoneRequired =>
      'Pakiusap ilagay ang iyong numero ng cellphone.';

  @override
  String get loginPasswordRequired => 'Pakiusap ilagay ang iyong password.';

  @override
  String get loginInvalidCredentials =>
      'Mali ang numero ng cellphone o password.';

  @override
  String get loginAccountPending => 'Sinusuri pa ang iyong account.';

  @override
  String loginAccountRejected(Object reason) {
    return 'Tinanggihan ang iyong account: $reason';
  }

  @override
  String loginWrongRole(Object role) {
    return 'Walang $role account para sa numerong ito.';
  }

  @override
  String get loginLogoutConfirm => 'Sigurado ka bang mag-logout?';

  @override
  String get driverStatus => 'Katayuan';

  @override
  String get driverStatusPending => 'Nakabinbin';

  @override
  String get driverStatusApproved => 'Inaprubahan';

  @override
  String get driverStatusRejected => 'Tinanggihan';

  @override
  String get driverPendingApproval => 'Nakabinbing Pag-apruba';

  @override
  String get driverPendingNote =>
      'Sinusuri ng aming team ang iyong mga dokumento. Karaniwang tumatagal ng 24-48 oras.';

  @override
  String get driverVerifiedBadge => 'Verified';

  @override
  String get driverVerifiedDriver => 'Verified na Driver';

  @override
  String get driverUnverified => 'Hindi pa na-verify';

  @override
  String driverRejectionReason(Object reason) {
    return 'Dahilan ng pagtanggi: $reason';
  }

  @override
  String get driverOnlineRestricted =>
      'Makakapag-online ka lamang kapag naaprubahan na ang iyong aplikasyon.';

  @override
  String get driverVerificationStatus => 'Katayuan ng Veripikasyon';

  @override
  String get driverDocumentsApproved => 'Inaprubahan ang mga Dokumento';

  @override
  String get regTitle => 'Maging Driver';

  @override
  String get regSubtitle => 'Kumita sa sariling oras';

  @override
  String get regStep1 => 'Personal';

  @override
  String get regStep2 => 'Lisensya';

  @override
  String get regStep3 => 'Sasakyan';

  @override
  String get regStep4 => 'Asosasyon';

  @override
  String get regStep5 => 'Dokumento';

  @override
  String get regFullName => 'Buong Pangalan';

  @override
  String get regFullNameHint => 'Juan Dela Cruz';

  @override
  String get regMobileNumber => 'Numero ng Cellphone';

  @override
  String get regMobileHint => '+63 912 345 6789';

  @override
  String get regPassword => 'Password';

  @override
  String get regPasswordHint => 'Hindi bababa sa 8 karakter';

  @override
  String get regDateOfBirth => 'Araw ng Kapanganakan';

  @override
  String get regSex => 'Kasarian';

  @override
  String get regMale => 'Lalaki';

  @override
  String get regFemale => 'Babae';

  @override
  String get regAddress => 'Kasalukuyang Tirahan';

  @override
  String get regAddressHint => 'Block, Lot, Kalye, Barangay, Lungsod...';

  @override
  String get regLicenseType => 'Uri ng Lisensya';

  @override
  String get regNonProfessional => 'Non-Professional';

  @override
  String get regProfessional => 'Professional';

  @override
  String get regLicenseNumber => 'Numero ng Lisensya';

  @override
  String get regLicenseNumberHint => 'N01-12-345678';

  @override
  String get regLicenseExpiry => 'Petsa ng Pagkawalang-bisa';

  @override
  String get regDlCodes => 'DL Codes';

  @override
  String get regConditionCodes => 'Condition Codes';

  @override
  String get regVehicleType => 'Uri ng Sasakyan';

  @override
  String get regPlateNumber => 'Numero ng Plaka';

  @override
  String get regMake => 'Gawa (Make)';

  @override
  String get regModel => 'Modelo';

  @override
  String get regYear => 'Taon';

  @override
  String get regColor => 'Kulay';

  @override
  String get regToda => 'Asosasyon ng TODA';

  @override
  String get regTodaHint => 'Piliin ang iyong TODA';

  @override
  String get regTodaNotListed => 'Wala sa listahan ang TODA ko';

  @override
  String get regBarangay => 'Barangay';

  @override
  String get regMunicipality => 'Munisipalidad';

  @override
  String get regProvince => 'Probinsya';

  @override
  String get regDocLicenseFront => 'Litrato ng Lisensya (Harap)';

  @override
  String get regDocLicenseBack => 'Litrato ng Lisensya (Likod)';

  @override
  String get regDocOrCr => 'Litrato ng OR/CR';

  @override
  String get regDocProfile => 'Litrato ng Profile';

  @override
  String get regUploadTap => 'I-tap para mag-upload';

  @override
  String get regUploaded => 'Na-upload na';

  @override
  String get regSubmitApplication => 'Isumite ang Aplikasyon';

  @override
  String regNextStep(Object step) {
    return 'Susunod: $step';
  }

  @override
  String get regPrevStep => 'Nauna';

  @override
  String get regApplicationSubmitted => 'Naisumite na ang Aplikasyon!';

  @override
  String get regApplicationSubmittedBody =>
      'Salamat! Nakabinbin na ang iyong aplikasyon. Abisuhan ka namin kapag na-verify na.';

  @override
  String get regBackToLogin => 'Bumalik sa Login';

  @override
  String get regFillRequired =>
      'Pakiusap punan ang lahat ng kinakailangang field.';

  @override
  String get regPasswordTooShort =>
      'Ang password ay dapat hindi bababa sa 8 karakter.';

  @override
  String get regUploadAllDocs =>
      'Pakiusap i-upload ang lahat ng kinakailangang dokumento.';

  @override
  String get regSuccessTitle => 'Welcome aboard!';

  @override
  String get regSuccessBody =>
      'Natanggap na ang iyong aplikasyon. Susuriin ng admin ang iyong mga dokumento sa loob ng 24-48 oras.';

  @override
  String get vehicleTricycle => 'Traysikel';

  @override
  String get vehicleHabal => 'Habal-Habal';

  @override
  String get vehicleTricycleSub => '3-4 na pasahero';

  @override
  String get vehicleHabalSub => '1-2 na pasahero';

  @override
  String get vehicleStartsAt => 'Nagsisimula sa';

  @override
  String get vehicleMinsAway => 'minuto ang layo';

  @override
  String vehicleAvailable(Object count) {
    return '$count ang available na malapit';
  }

  @override
  String get vehicleChooseType => 'Piliin ang iyong sasakyan';

  @override
  String get vehicleBaseFare => 'Base Fare';

  @override
  String get vehiclePerKm => 'Bawat km';

  @override
  String get bookingPickup => 'Kung saan ka sasakay';

  @override
  String get bookingDropoff => 'Kung saan ka bababa';

  @override
  String get bookingEnterPickup => 'Ilagay ang pickup location';

  @override
  String get bookingEnterDropoff => 'Ilagay ang destinasyon';

  @override
  String get bookingUseCurrentLocation => 'Gamitin ang kasalukuyang lokasyon';

  @override
  String get bookingSearchingDrivers => 'Hinahanap ang driver...';

  @override
  String bookingSearchingBody(Object vehicle) {
    return 'Hinahanap namin ang pinakamalapit na $vehicle para sa iyo.';
  }

  @override
  String get bookingCancelBooking => 'Kanselahin ang Booking';

  @override
  String get bookingCancelConfirm => 'Kanselahin ang ride request na ito?';

  @override
  String get bookingEstimatedFare => 'Tinatayang Fare';

  @override
  String get bookingEstimatedDistance => 'Tinatayang distansya';

  @override
  String get bookingEstimatedDuration => 'Tinatayang oras ng biyahe';

  @override
  String get bookingBookNow => 'Mag-book Ngayon';

  @override
  String get bookingRequestRide => 'Mag-request ng Sakay';

  @override
  String get bookingChooseVehicle => 'Pumili ng Sasakyan';

  @override
  String get bookingSelectPayment => 'Pumili ng Paraan ng Pagbabayad';

  @override
  String get bookingPaymentNote =>
      'Pwede kang magbayad ng cash o anumang digital wallet.';

  @override
  String get bookingLocationRequired =>
      'Pakiusap itakda ang iyong pickup at destinasyon.';

  @override
  String get bookingConfirmed => 'Matagumpay ang booking';

  @override
  String get bookingRequestQueued =>
      'Offline ka. Naka-queue ang iyong ride request at ipapadala kapag nag-reconnect ka na.';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentGcash => 'GCash';

  @override
  String get paymentMaya => 'PayMaya';

  @override
  String get paymentCard => 'Credit / Debit Card';

  @override
  String get paymentMethods => 'Paraan ng Pagbabayad';

  @override
  String get paymentPayNow => 'Magbayad Ngayon';

  @override
  String paymentPayFare(Object amount) {
    return 'Bayaran ang $amount';
  }

  @override
  String get paymentAddCard => 'Magdagdag ng Card';

  @override
  String get paymentCardNumber => 'Numero ng Card';

  @override
  String get paymentCardHolder => 'Pangalan ng May-ari ng Card';

  @override
  String get paymentExpiry => 'Pagkawalang-bisa';

  @override
  String get paymentCvv => 'CVV';

  @override
  String get paymentCardAdded => 'Matagumpay ang pagdagdag ng card';

  @override
  String get paymentGcashConfirm =>
      'Ire-redirect ka sa GCash para makumpleto ang pagbabayad.';

  @override
  String get paymentMayaConfirm =>
      'Ire-redirect ka sa PayMaya para makumpleto ang pagbabayad.';

  @override
  String get paymentSuccess => 'Matagumpay ang Pagbabayad';

  @override
  String paymentSuccessBody(Object amount) {
    return 'Naproseso na ang iyong bayad na $amount. Salamat sa pagsakay sa Sakay Ta!';
  }

  @override
  String get paymentFailed => 'Nabigo ang Pagbabayad';

  @override
  String get paymentFailedBody =>
      'Pakiusap suriin ang iyong paraan ng pagbabayad at subukang muli.';

  @override
  String get paymentChoose => 'Pumili ng paraan ng pagbabayad';

  @override
  String get paymentDriverConfirmation => 'Kumpirmasyon ng driver';

  @override
  String paymentReceivedCash(Object amount) {
    return 'Kinumpirma ng driver ang pagtanggap ng ₱$amount cash.';
  }

  @override
  String get paymentHistory => 'Kasaysayan ng Pagbabayad';

  @override
  String paymentPaidVia(Object method) {
    return 'Binayaran gamit ang $method';
  }

  @override
  String get paymentReceiptTitle => 'Digital na Resibo';

  @override
  String get paymentReceiptNo => 'Numero ng Resibo';

  @override
  String get paymentTripDate => 'Petsa ng Biyahe';

  @override
  String get paymentFareCharged => 'Singil na Fare';

  @override
  String get paymentTotalPaid => 'Kabuuang Bayad';

  @override
  String get paymentThankYou => 'Salamat sa pagsakay sa Sakay Ta!';

  @override
  String get paymentReceiptSent => 'Ipinadala ang resibo sa iyong email';

  @override
  String get trackingTitle => 'Pagsubay sa Biyahe';

  @override
  String get trackingSearching => 'Hinahanap ang iyong driver...';

  @override
  String get trackingAccepted => 'Natagpuan ang driver!';

  @override
  String trackingAcceptedBody(Object driver) {
    return '$driver ay papunta na sa iyong pickup.';
  }

  @override
  String get trackingArrived => 'Dumating na ang iyong driver';

  @override
  String get trackingStarted => 'Papunta na sa iyong destinasyon';

  @override
  String get trackingCompleted => 'Tapos na ang biyahe';

  @override
  String get trackingDriverOnTheWay => 'Papunta na ang iyong driver';

  @override
  String get trackingEta => 'ETA';

  @override
  String get trackingMinsAway => 'MINUTO ANG NANANATILI';

  @override
  String get trackingDriverInfo => 'Driver';

  @override
  String get trackingPlateNumber => 'Numero ng Plaka';

  @override
  String get trackingRating => 'Rating';

  @override
  String get trackingMessage => 'Mensahe';

  @override
  String get trackingCall => 'Tawag';

  @override
  String get trackingMaskedCall => 'Masked na tawag';

  @override
  String get trackingShareTrip => 'I-share ang Detalye ng Biyahe';

  @override
  String trackingShareBody(
      Object driver, Object eta, Object plate, Object vehicle) {
    return 'Sasakay ako sa Sakay Ta! $vehicle · $plate · $driver · ETA $eta min. Subaybayan mo ako live sa app.';
  }

  @override
  String get trackingEndTrip => 'Tapusin ang Biyahe';

  @override
  String get trackingStartRide => 'Simulan ang Biyahe';

  @override
  String get trackingMarkArrived => 'Dumating Na Ako';

  @override
  String get trackingPickup => 'PICKUP';

  @override
  String get trackingDropoff => 'DROPOFF';

  @override
  String get trackingYourLocation => 'Iyong lokasyon';

  @override
  String get trackingShareTitle => 'Sakay Ta — Live na Biyahe';

  @override
  String get trackingStatusSearching => 'Hinahanap';

  @override
  String get trackingStatusAccepted => 'Tinanggap';

  @override
  String get trackingStatusArrived => 'Dumating';

  @override
  String get trackingStatusStarted => 'Nagsimula';

  @override
  String get trackingStatusCompleted => 'Tapos';

  @override
  String trackingChatWithDriver(Object driver) {
    return 'Makipag-chat kay $driver';
  }

  @override
  String get trackingChatHint => 'Mag-type ng mensahe...';

  @override
  String get trackingNoChats =>
      'Wala pang mensahe. Kamustahin mo ang driver mo!';

  @override
  String get trackingRateDriver => 'I-rate ang iyong driver';

  @override
  String get trackingRateTitle => 'Kumusta ang iyong biyahe?';

  @override
  String get trackingRateSubmit => 'Isumite ang Rating';

  @override
  String get trackingThanksFeedback => 'Salamat sa iyong feedback!';

  @override
  String get trackingCancelRide => 'Kanselahin ang Ride';

  @override
  String get trackingRideCancelled => 'Kinansela ang ride';

  @override
  String get ridesUpcoming => 'Paparating';

  @override
  String get ridesHistory => 'Kasaysayan';

  @override
  String get ridesNoUpcoming => 'Walang paparating na rides';

  @override
  String get ridesNoUpcomingBody =>
      'Handa ka na ba? Mag-book ng ride para makita ito dito.';

  @override
  String get ridesNoHistory => 'Wala pang biyahe';

  @override
  String get ridesNoHistoryBody =>
      'Lalabas dito ang iyong mga natapos na biyahe.';

  @override
  String get ridesCompleted => 'Tapos';

  @override
  String get ridesCancelled => 'Kinansela';

  @override
  String get ridesViewDetails => 'Tingnan ang Detalye';

  @override
  String get ridesRideHistory => 'Kasaysayan ng mga Sakay';

  @override
  String get ridesRebook => 'Mag-book Muli';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEdit => 'I-edit ang Profile';

  @override
  String get profilePaymentMethods => 'Paraan ng Pagbabayad';

  @override
  String get profileSavedPlaces => 'Mga Naka-save na Lugar';

  @override
  String get profileSavedPlacesDetail => 'Bahay, Trabaho';

  @override
  String get profilePreferencesSupport => 'Mga Kagustuhan at Suporta';

  @override
  String get profileHelpCenter => 'Sentro ng Tulong';

  @override
  String get profileAccountSettings => 'Mga Setting ng Account';

  @override
  String get profileHistory => 'Kasaysayan';

  @override
  String get profileTrustedPassenger => 'Pinagkakatiwalaang Pasahero';

  @override
  String get profileVerifiedPassenger => 'Verified na Pasahero';

  @override
  String get profileLanguageDetail => 'Kagustuhan sa Wika';

  @override
  String get profileLanguageLabel => 'Wika ng App';

  @override
  String get profileDarkMode => 'Dark Mode';

  @override
  String get profileNotifications => 'Mga Notipikasyon';

  @override
  String get profileAbout => 'Tungkol sa Sakay Ta';

  @override
  String get profileVersion => 'Bersyon';

  @override
  String get profileTotalRides => 'Kabuuang mga Sakay';

  @override
  String get profileJoinedSince => 'Miyembro Mula';

  @override
  String get profilePersonalInfo => 'Personal na Impormasyon';

  @override
  String get profileFullName => 'Buong Pangalan';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileMobile => 'Numero ng Cellphone';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletTotalBalance => 'KABUUANG AVAILABLE NA BALANCE';

  @override
  String get walletCashEarnings => 'Cash na Kita';

  @override
  String get walletDigitalEarnings => 'Digital (e-wallet)';

  @override
  String get walletWithdraw => 'Mag-withdraw';

  @override
  String get walletRecentTransactions => 'Mga Kamakailang Transaksyon';

  @override
  String get walletTransactionHistory => 'Kasaysayan ng Transaksyon';

  @override
  String get walletWithdrawTo => 'I-withdraw Sa';

  @override
  String get walletGcash => 'GCash';

  @override
  String get walletBank => 'Bank Transfer';

  @override
  String get walletEnterAmount => 'Ilagay ang halaga';

  @override
  String get walletMinMax => 'Min ₱100 · Max ₱50,000 kada transaksyon';

  @override
  String get walletWithdrawAmount => 'Halaga ng Withdraw';

  @override
  String get walletProcessing => 'Pinoproseso ang iyong withdrawal...';

  @override
  String get walletSuccess => 'Matagumpay ang Withdrawal';

  @override
  String walletSuccessBody(Object amount, Object method) {
    return 'Naipadala na ang ₱$amount sa iyong $method account.';
  }

  @override
  String get walletInsufficient => 'Hindi sapat ang balance.';

  @override
  String walletInsufficientBody(Object amount) {
    return 'Ang iyong available na balance ay ₱$amount lamang.';
  }

  @override
  String get walletNoHistory => 'Wala pang transaksyon';

  @override
  String get walletFilterAll => 'Lahat';

  @override
  String get walletFilterIncoming => 'Kita';

  @override
  String get walletFilterWithdrawal => 'Mga Withdraw';

  @override
  String get walletDaily => 'Araw-araw';

  @override
  String get walletWeekly => 'Kada Linggo';

  @override
  String get walletMonthly => 'Kada Buwan';

  @override
  String get earningsTitle => 'Kita';

  @override
  String get earningsToday => 'Ngayon';

  @override
  String get earningsThisWeek => 'Sa Linggong Ito';

  @override
  String get earningsThisMonth => 'Sa Buwang Ito';

  @override
  String get earningsTotalEarnings => 'Kabuuang Kita';

  @override
  String get earningsNetEarnings => 'Kita sa Biyahe';

  @override
  String get earningsCommission => 'Kita sa Pasahe';

  @override
  String get earningsFare => 'Fare';

  @override
  String get earningsTrips => 'Mga Biyahe';

  @override
  String get earningsHoursOnline => 'Oras na Online';

  @override
  String earningsTripsCount(Object count) {
    return '$count na biyahe';
  }

  @override
  String earningsTripsAndHours(Object hours, Object trips) {
    return '$trips na biyahe · $hours na oras';
  }

  @override
  String get earningsTodayEarnings => 'Kita Ngayong Araw';

  @override
  String earningsUpFromYesterday(Object pct) {
    return '+$pct% kumpara kahapon';
  }

  @override
  String earningsDownFromYesterday(Object pct) {
    return '$pct% kumpara kahapon';
  }

  @override
  String get earningsWeeklySummary => 'Buod ng Linggo';

  @override
  String get earningsDailyBreakdown => 'Araw-araw na breakdown';

  @override
  String get earningsNoEarnings => 'Wala pang kita sa panahong ito';

  @override
  String get earningsLifetime => 'Kabuuang Kita Mula Noon';

  @override
  String get earningsCompletedTrips => 'Mga Natapos na Biyahe';

  @override
  String get performanceTitle => 'Performance';

  @override
  String get performanceStats => 'Mga Estadistika ng Performance';

  @override
  String get performanceYourPerformance => 'Iyong Performance';

  @override
  String get performanceRating => 'Rating';

  @override
  String get performanceAcceptance => 'Pagtanggap';

  @override
  String get performanceAcceptanceRate => 'Rate ng Pagtanggap';

  @override
  String get performanceAccuracy => 'Katumpakan';

  @override
  String get performanceAccuracyRate => 'Pagsapit sa Oras';

  @override
  String get performanceCancellation => 'Kanselasyon';

  @override
  String get performanceTotalTrips => 'Kabuuang mga Biyahe';

  @override
  String get performanceLifetimeEarnings => 'Kabuuang Kita Mula Noon';

  @override
  String get performanceWeeklyComparison => 'Paghahambing sa Linggo';

  @override
  String get performanceLastWeek => 'Nakaraang Linggo';

  @override
  String get performanceCurrentWeek => 'Linggong Ito';

  @override
  String get performanceTripsEarnings => 'Mga Biyahe at Kita';

  @override
  String get performanceFeedback => 'Feedback ng Pasahero';

  @override
  String get performanceSeeAll => 'Tingnan lahat';

  @override
  String get performanceTopTier => 'Top Tier';

  @override
  String get performanceAverage => 'Katamtaman';

  @override
  String get performanceExcellent => 'Napakahusay';

  @override
  String get performanceLow => 'Mababa';

  @override
  String get performanceBadges => 'Mga Badge at Nakamit';

  @override
  String get performanceAchievement1 => 'Road Warrior';

  @override
  String get performanceAchievement1Desc => '100 na biyahe ang natapos';

  @override
  String get performanceAchievement2 => 'Early Bird';

  @override
  String get performanceAchievement2Desc => 'Unang biyahe bago mag 7 AM';

  @override
  String get performanceAchievement3 => 'Star Rider';

  @override
  String get performanceAchievement3Desc => '5.0 na average na rating';

  @override
  String get performanceAchievement4 => 'Weekend Hero';

  @override
  String get performanceAchievement4Desc => '20 na biyahe sa isang weekend';

  @override
  String get performanceAchievement5 => 'Safe Driver';

  @override
  String get performanceAchievement5Desc => '100 na biyahe na walang reklamo';

  @override
  String get performanceLocked => 'Naka-lock';

  @override
  String performanceTierLabel(Object tier) {
    return 'Tier: $tier';
  }

  @override
  String get performanceLguCompliance => 'Pagsang-ayon ng LGU';

  @override
  String get performanceLguActive => 'Aktibo at verified';

  @override
  String get adminTitle => 'Admin Dashboard';

  @override
  String get adminDrivers => 'Mga Driver';

  @override
  String get adminPassengers => 'Mga Pasahero';

  @override
  String get adminTotalTrips => 'Kabuuang mga Biyahe';

  @override
  String get adminTotalRevenue => 'Kita ng Platform';

  @override
  String get adminPendingReviews => 'Nakabinbing mga Review';

  @override
  String get adminApprovedDrivers => 'Inaprubahang mga Driver';

  @override
  String get adminRejectedDrivers => 'Tinanggihang mga Driver';

  @override
  String get adminApprove => 'Aprubahan';

  @override
  String get adminReject => 'Tanggihan';

  @override
  String get adminRejectReason => 'Dahilan ng pagtanggi (opsyonal)';

  @override
  String get adminRejectPrompt =>
      'Tanggihan ang driver na ito? Abisuhan sila gamit ang iyong dahilan.';

  @override
  String get adminApprovePrompt =>
      'Aprubahan ang driver na ito? Makakapag-online sila agad.';

  @override
  String get adminDriverApproved => 'Inaprubahan ang driver';

  @override
  String get adminDriverRejected => 'Tinanggihan ang driver';

  @override
  String get adminViewDetails => 'Tingnan ang Detalye';

  @override
  String get adminManageDrivers => 'Pamahalaan ang mga Driver';

  @override
  String get adminDriverId => 'ID ng Driver';

  @override
  String get adminSubmittedAt => 'Isinumite';

  @override
  String get adminTodaReports => 'Mga Ulat ng TODA';

  @override
  String get adminTodaTitle => 'Pamamahala ng TODA';

  @override
  String get adminAddToda => 'Magdagdag ng TODA';

  @override
  String get adminEditToda => 'I-edit ang TODA';

  @override
  String get adminDeleteToda => 'Tanggalin ang TODA';

  @override
  String get adminTodaName => 'Pangalan ng TODA';

  @override
  String get adminTodaLeader => 'Pangalan ng Lider';

  @override
  String get adminTodaContact => 'Numero ng Kontak';

  @override
  String get adminTodaArea => 'Lugar na Pinaglilingkuran';

  @override
  String get adminTodaMembers => 'Mga Miyembro';

  @override
  String get adminDeleteTodaConfirm => 'Tanggalin ang TODA na ito?';

  @override
  String get adminTodaAdded => 'Idinagdag ang TODA';

  @override
  String get adminTodaUpdated => 'Na-update ang TODA';

  @override
  String get adminTodaDeleted => 'Natanggal ang TODA';

  @override
  String get adminLguPartnerships => 'Pakikipagtulungan sa LGU';

  @override
  String get adminAddPartnership => 'Magdagdag ng Pakikipagtulungan';

  @override
  String get adminPartnershipName => 'LGU / Munisipalidad';

  @override
  String get adminPartnershipActive => 'Aktibo';

  @override
  String get adminPartnershipInactive => 'Hindi Aktibo';

  @override
  String get adminReports => 'Mga Ulat';

  @override
  String get adminReportsByToda => 'Mga Ulat kada TODA';

  @override
  String get adminDriverCount => 'Mga Driver';

  @override
  String get adminTripCount => 'Mga Biyahe';

  @override
  String get adminRevenue => 'Kita';

  @override
  String get adminAvgRating => 'Average na Rating';

  @override
  String get adminExport => 'I-export ang Ulat';

  @override
  String get adminExported => 'Na-export ang ulat';

  @override
  String get offlineTitle => 'Offline ka';

  @override
  String get offlineBody =>
      'Offline ka ngayon. Ipinapakita ang naka-cache na datos.';

  @override
  String get offlineReconnecting => 'Nag-reconnect...';

  @override
  String get offlineBackOnline => 'Bumalik online';

  @override
  String offlineQueuedRequests(Object count) {
    return 'Naka-queue na requests: $count';
  }

  @override
  String get offlineSyncing =>
      'Pinoproseso ang iyong naka-queue na requests...';

  @override
  String get offlineSynced => 'Na-sync na ang lahat ng naka-queue na requests';

  @override
  String get offlineCached => 'Naka-cache na datos';

  @override
  String get offlineWaiting => 'Naghihintay ng koneksyon...';

  @override
  String get mapLabel => 'Mapa';

  @override
  String get mapOfflineNotice => 'Ipinapakita ang naka-cache na mapa';

  @override
  String get notifRideRequest => 'Bagong ride request';

  @override
  String get notifPaymentReceived => 'Natanggap ang bayad';

  @override
  String get notifAccountApproved => 'Inaprubahan na ang iyong account!';

  @override
  String get notifAccountRejected => 'Tinanggihan ang iyong account';

  @override
  String get notifDriverArrived => 'Dumating ang driver';

  @override
  String get notifTripCompleted => 'Tapos na ang biyahe';

  @override
  String notifChat(Object name) {
    return 'Bagong mensahe mula kay $name';
  }

  @override
  String get notifTitle => 'Mga Notipikasyon';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatYou => 'Ikaw';

  @override
  String get chatDriver => 'Driver';

  @override
  String get chatTypeMessage => 'Mag-type ng mensahe...';

  @override
  String get chatSend => 'Ipadala';

  @override
  String get chatNoMessages => 'Wala pang mensahe';

  @override
  String get langEn => 'English';

  @override
  String get langCeb => 'Cebuano';

  @override
  String get langTl => 'Tagalog';

  @override
  String get langAppLanguage => 'Wika ng App';

  @override
  String get langChanged => 'Nagbago na ang wika';

  @override
  String get signUpPassengerTitle => 'Mag-sign up bilang Pasahero';

  @override
  String get signUpPassengerSubtitle =>
      'Mag-sign up upang magsimula sa pag-book ng iyong mga biyahe.';

  @override
  String get signUpFullName => 'Buong Pangalan';

  @override
  String get signUpFullNameHint => 'hal. Juan Dela Cruz';

  @override
  String get signUpFullNameError =>
      'Pakilagay ang iyong buong pangalan (di bababa sa 2 letra).';

  @override
  String get signUpMobileNumber => 'Numero ng Telepono';

  @override
  String get signUpMobileHint => '09XX XXX XXXX';

  @override
  String get signUpMobileError =>
      'Pakilagay ang tamang 11-digit na numero ng telepono.';

  @override
  String get signUpPassword => 'Password';

  @override
  String get signUpPasswordHint => 'Di bababa sa 6 na karakter';

  @override
  String get signUpPasswordError =>
      'Ang password ay dapat di bababa sa 6 na karakter.';

  @override
  String get signUpConfirmPassword => 'Kumpirmahin ang Password';

  @override
  String get signUpConfirmPasswordHint => 'I-retype ang iyong password';

  @override
  String get signUpConfirmPasswordError => 'Hindi magkatugma ang mga password.';

  @override
  String get signUpTermsText =>
      'Sumasang-ayon ako sa Mga Tuntunin at Kundisyon at Patakaran sa Pagkapribado';

  @override
  String get signUpTermsRequired =>
      'Kailangan mong sumang-ayon sa Mga Tuntunin at Kundisyon upang magpatuloy.';

  @override
  String get signUpButton => 'Mag-sign up';

  @override
  String get signUpAlreadyHaveAccount => 'May account ka na? ';

  @override
  String get signUpLoginLink => 'Mag-login';

  @override
  String get signUpPreferredLanguage => 'Piniling Wika';

  @override
  String get navHome => 'Tahanan';

  @override
  String get navActivity => 'Aktibidad';

  @override
  String get navWallet => 'Pitaka';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileClearCache => 'Linisin ang Cache';

  @override
  String get profileClearCacheSubtitle =>
      'Magbakante ng pansamantalang files at cache ng mapa';

  @override
  String profileClearCacheSuccess(Object size) {
    return 'Matagumpay na nalinis ang cache! ($size ang nabakante)';
  }

  @override
  String get profileClearCacheConfirm =>
      'Linisin ang pansamantalang cache? Mananatiling ligtas ang iyong account at mga tala ng biyahe.';

  @override
  String get profileLogoutTitle => 'Mag-log Out';

  @override
  String get profileLogoutSubtitle => 'Mag-sign out sa device na ito';

  @override
  String get profileLogoutMessage =>
      'Sigurado ka bang nais mong mag-log out? Ang iyong account at mga tala ng biyahe ay ligtas na naka-save sa server.';

  @override
  String get profileLogoutButton => 'Mag-log Out';

  @override
  String get profileDeleteAccountTitle => 'Burahin ang Account';

  @override
  String get profileDeleteAccountSubtitle =>
      'Permanenteng burahin ang iyong account at data sa server';

  @override
  String get profileDeleteAccountWarning =>
      'Sigurado ka bang nais mong permanenteng burahin ang iyong Sakay Ta account? Hindi na ito mababawi at permanenteng tatanggalin ang iyong profile, kasaysayan ng biyahe, at naka-save na datos mula sa aming mga server.';

  @override
  String get profileDeleteAccountConfirmButton => 'Permanenteng Burahin';

  @override
  String get profileDeleteAccountSuccess =>
      'Matagumpay na nabura ang iyong account.';

  @override
  String get profileSelectLanguage => 'Pumili ng Wika';

  @override
  String get profileBisayaLanguage => 'Bisaya (Binisaya / Cebuano)';

  @override
  String get profileEnglishLanguage => 'English (US / PH)';

  @override
  String get profileTagalogLanguage => 'Tagalog (Filipino)';

  @override
  String get profileDangerZone => 'Panganib na Sona';

  @override
  String get homeGreetingMorning => 'Magandang Umaga!';

  @override
  String get homeGreetingAfternoon => 'Magandang Hapon!';

  @override
  String get homeGreetingEvening => 'Magandang Gabi!';

  @override
  String get homeWhereTo => 'Saan pupunta?';

  @override
  String get homeSearchDestination => 'Maghanap ng destinasyon...';

  @override
  String get homeQuickDestinations => 'Mabilisang Destinasyon';

  @override
  String get homeRecentActivity => 'Kamakailang Aktibidad';

  @override
  String get homeNearbyDrivers => 'Mga Drayber sa Malapit';

  @override
  String get homeNoNearbyDrivers =>
      'Walang aktibong drayber sa iyong lugar ngayon.';

  @override
  String get homeBookRide => 'Mag-book ng Biyahe';

  @override
  String get homeCurrentLocation => 'Kasalukuyang Lokasyon';

  @override
  String get homePopularPlaces => 'Mga Sikat na Lugar';

  @override
  String get walletCashIn => 'Mag-top Up';

  @override
  String get walletSendMoney => 'Maglipat';

  @override
  String get walletAddPaymentMethod => 'Magdagdag ng Paraan ng Pagbayad';

  @override
  String get walletLinkedAccounts => 'Mga Nakakabit na Account';

  @override
  String get walletDefaultPayment => 'Pangunahing Pagbayad';

  @override
  String get walletManagePayments => 'Pamahalaan ang Paraan ng Pagbayad';

  @override
  String get walletSavedAccounts => 'Mga Naka-save na Account';

  @override
  String get walletHistoryReceipts => 'Kasaysayan ng Pagbayad at Resibo';

  @override
  String get walletNoRecords => 'Wala pang talaan ng pagbayad.';

  @override
  String get ridesEmptyUpcoming => 'Walang paparating na biyahe';

  @override
  String get ridesEmptyUpcomingSubtitle =>
      'Handa nang umalis? Mag-book ng biyahe upang makita ito rito.';

  @override
  String get ridesEmptyCompleted => 'Wala pang natapos na biyahe';

  @override
  String get ridesEmptyCompletedSubtitle =>
      'Ang iyong mga resibo at kasaysayan ng natapos na biyahe ay lalabas dito.';

  @override
  String get ridesEmptyCancelled => 'Walang nakanselang biyahe';

  @override
  String get ridesEmptyCancelledSubtitle =>
      'Ang mga nakanselang biyahe ay lalabas dito.';

  @override
  String get ridesBookNow => 'Mag-book ng Biyahe Ngayon';
}
