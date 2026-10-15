// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Cebuano (`ceb`).
class AppLocalizationsCeb extends AppLocalizations {
  AppLocalizationsCeb([String locale = 'ceb']) : super(locale);

  @override
  String get appName => 'Sakay Ta';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Kanselahon';

  @override
  String get commonSave => 'Tipigi';

  @override
  String get commonNext => 'Sunod';

  @override
  String get commonBack => 'Balik';

  @override
  String get commonContinue => 'Padayon';

  @override
  String get commonSubmit => 'Isumitir';

  @override
  String get commonSearch => 'Pangitaa';

  @override
  String get commonDone => 'Human na';

  @override
  String get commonDelete => 'Papason';

  @override
  String get commonEdit => 'Usba';

  @override
  String get commonViewAll => 'Tan-awon Tanan';

  @override
  String get commonAll => 'Tanan';

  @override
  String get commonClose => 'Isira';

  @override
  String get commonConfirm => 'Kompidmaron';

  @override
  String get commonLogout => 'Log Out';

  @override
  String get commonLanguage => 'Pinulongan';

  @override
  String get commonRetry => 'Sulayi Usab';

  @override
  String get commonTryAgain => 'Sulayi Usab';

  @override
  String get commonLoading => 'Nagkarga...';

  @override
  String get commonError => 'Adunay nasayop';

  @override
  String get commonNotAvailable => 'Wala magamit';

  @override
  String get commonNoData => 'Walay datos';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOptional => '(opsyonal)';

  @override
  String get commonSkip => 'Laktawan';

  @override
  String get commonAdd => 'Dugangi';

  @override
  String get commonSelect => 'Pilia';

  @override
  String get commonUpload => 'I-upload';

  @override
  String get commonDetails => 'Mga Detalye';

  @override
  String get commonSettings => 'Mga Setting';

  @override
  String get commonEmpty => 'Wala pa bisan unsa';

  @override
  String get rolePassenger => 'Pasahero';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginGreeting => 'Maayong Buntag!';

  @override
  String get loginSubtitlePassenger => 'Login aron makasakay.';

  @override
  String get loginSubtitleDriver => 'Login aron makakita.';

  @override
  String get loginSubtitleAdmin => 'Login aron madumala ang Sakay Ta.';

  @override
  String get loginMobileNumber => 'Numero sa Selpon';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginMobileHint => '+63 9XX XXX XXXX';

  @override
  String get loginForgotPassword => 'Nakalimot sa Password?';

  @override
  String get loginLoginButton => 'Log In';

  @override
  String get loginNoAccount => 'Wala kay account? Paghimo og account karon';

  @override
  String get loginLanguageLabel => 'Pinulongan';

  @override
  String get loginDemoAccounts => 'Demo nga Account';

  @override
  String get loginDemoPassenger => 'Pasahero Demo';

  @override
  String get loginDemoDriver => 'Driver Demo';

  @override
  String get loginDemoAdmin => 'Admin Demo';

  @override
  String get loginPhoneRequired => 'Palihug isulod ang imong numero sa selpon.';

  @override
  String get loginPasswordRequired => 'Palihug isulod ang imong password.';

  @override
  String get loginInvalidCredentials =>
      'Sayop nga numero sa selpon o password.';

  @override
  String get loginAccountPending => 'Gisusi pa ang imong account.';

  @override
  String loginAccountRejected(Object reason) {
    return 'Gibalibaran ang imong account: $reason';
  }

  @override
  String loginWrongRole(Object role) {
    return 'Wala\'y $role account para sa kini nga numero.';
  }

  @override
  String get loginLogoutConfirm => 'Sigurado ka nga gusto moka log out?';

  @override
  String get driverStatus => 'Status';

  @override
  String get driverStatusPending => 'Pending';

  @override
  String get driverStatusApproved => 'Gi-aprubahan';

  @override
  String get driverStatusRejected => 'Gibali-barahan';

  @override
  String get driverPendingApproval => 'Gisusi pa';

  @override
  String get driverPendingNote =>
      'Gisusi pa sa among team ang imong mga dokumento. Kasagaran 24-48 ka oras.';

  @override
  String get driverVerifiedBadge => 'Verified';

  @override
  String get driverVerifiedDriver => 'Verified nga Driver';

  @override
  String get driverUnverified => 'Wala pa na-verify';

  @override
  String driverRejectionReason(Object reason) {
    return 'Rason sa pagbalibad: $reason';
  }

  @override
  String get driverOnlineRestricted =>
      'Maka-online ka lamang kon maaprubahan na ang imong aplikasyon.';

  @override
  String get driverVerificationStatus => 'Status sa Veripikasyon';

  @override
  String get driverDocumentsApproved => 'Gi-aprubahan ang mga Dokumento';

  @override
  String get regTitle => 'Mahimong Driver';

  @override
  String get regSubtitle => 'Makakita ka sa imong kaugalingong oras';

  @override
  String get regStep1 => 'Personal';

  @override
  String get regStep2 => 'Lisensya';

  @override
  String get regStep3 => 'Sakyanan';

  @override
  String get regStep4 => 'Asosasyon';

  @override
  String get regStep5 => 'Dokumento';

  @override
  String get regFullName => 'Tibuok Ngalan';

  @override
  String get regFullNameHint => 'Juan Dela Cruz';

  @override
  String get regMobileNumber => 'Numero sa Selpon';

  @override
  String get regMobileHint => '+63 912 345 6789';

  @override
  String get regPassword => 'Password';

  @override
  String get regPasswordHint => 'Minimum 8 ka karakter';

  @override
  String get regDateOfBirth => 'Adlaw nga Natawhan';

  @override
  String get regSex => 'Sekso';

  @override
  String get regMale => 'Lalaki';

  @override
  String get regFemale => 'Babaye';

  @override
  String get regAddress => 'Kasalukuyang Adres';

  @override
  String get regAddressHint => 'Block, Lot, Dalan, Barangay, Dakbayan...';

  @override
  String get regLicenseType => 'Tipo sa Lisensya';

  @override
  String get regNonProfessional => 'Non-Professional';

  @override
  String get regProfessional => 'Professional';

  @override
  String get regLicenseNumber => 'Numero sa Lisensya';

  @override
  String get regLicenseNumberHint => 'N01-12-345678';

  @override
  String get regLicenseExpiry => 'Kataposan sa Lisensya';

  @override
  String get regDlCodes => 'DL Codes';

  @override
  String get regConditionCodes => 'Condition Codes';

  @override
  String get regVehicleType => 'Tipo sa Sakyanan';

  @override
  String get regPlateNumber => 'Numero sa Plaka';

  @override
  String get regMake => 'Paghimo (Make)';

  @override
  String get regModel => 'Modelo';

  @override
  String get regYear => 'Tuig';

  @override
  String get regColor => 'Kolor';

  @override
  String get regToda => 'Asosasyon sa TODA';

  @override
  String get regTodaHint => 'Pilia ang imong TODA';

  @override
  String get regTodaNotListed => 'Wala sa lista ang akong TODA';

  @override
  String get regBarangay => 'Barangay';

  @override
  String get regMunicipality => 'Munisipalidad';

  @override
  String get regProvince => 'Probinsya';

  @override
  String get regDocLicenseFront => 'Litrato sa Lisensya (Atubangan)';

  @override
  String get regDocLicenseBack => 'Litrato sa Lisensya (Likod)';

  @override
  String get regDocOrCr => 'Litrato sa OR/CR';

  @override
  String get regDocProfile => 'Litrato sa Profile';

  @override
  String get regUploadTap => 'I-tap aron i-upload';

  @override
  String get regUploaded => 'Na-upload na';

  @override
  String get regSubmitApplication => 'Isumitir ang Aplikasyon';

  @override
  String regNextStep(Object step) {
    return 'Sunod: $step';
  }

  @override
  String get regPrevStep => 'Nauna';

  @override
  String get regApplicationSubmitted => 'Nahuman na ang Aplikasyon!';

  @override
  String get regApplicationSubmittedBody =>
      'Salamat! Gisusi na karon ang imong aplikasyon. Pahibalo-on ka namo kon ma-verify na.';

  @override
  String get regBackToLogin => 'Balik sa Login';

  @override
  String get regFillRequired =>
      'Palihug pun-a ang tanang gikinahanglan nga pahina.';

  @override
  String get regPasswordTooShort =>
      'Ang password kinahanglan labing menos 8 ka karakter.';

  @override
  String get regUploadAllDocs =>
      'Palihug i-upload ang tanang gikinahanglan nga dokumento.';

  @override
  String get regSuccessTitle => 'Welcome aboard!';

  @override
  String get regSuccessBody =>
      'Nadawat na ang imong aplikasyon. Susihon sa admin ang imong mga dokumento sulud 24-48 ka oras.';

  @override
  String get vehicleTricycle => 'Trisikad';

  @override
  String get vehicleHabal => 'Habal-Habal';

  @override
  String get vehicleTricycleSub => '3-4 ka pasahero';

  @override
  String get vehicleHabalSub => '1-2 ka pasahero';

  @override
  String get vehicleStartsAt => 'Magsugod sa';

  @override
  String get vehicleMinsAway => 'ka min ang gilay-on';

  @override
  String vehicleAvailable(Object count) {
    return '$count ang magamit duol';
  }

  @override
  String get vehicleChooseType => 'Pilia ang imong sakyan';

  @override
  String get vehicleBaseFare => 'Base Fare';

  @override
  String get vehiclePerKm => 'Tungod sa km';

  @override
  String get bookingPickup => 'Asa ka magsakay';

  @override
  String get bookingDropoff => 'Asa ka paingon';

  @override
  String get bookingEnterPickup => 'Isulod ang lugar nga sakayan';

  @override
  String get bookingEnterDropoff => 'Isulod ang destinasyon';

  @override
  String get bookingUseCurrentLocation => 'Gamita ang karon nga lokasyon';

  @override
  String get bookingSearchingDrivers => 'Nangita og driver...';

  @override
  String bookingSearchingBody(Object vehicle) {
    return 'Gipangita namo ang labing duol nga $vehicle para nimo.';
  }

  @override
  String get bookingCancelBooking => 'Kanselahon ang Booking';

  @override
  String get bookingCancelConfirm => 'Kanselahon kini nga ride request?';

  @override
  String get bookingEstimatedFare => 'Gibana-bana nga Fare';

  @override
  String get bookingEstimatedDistance => 'Gibana-bana nga distansya';

  @override
  String get bookingEstimatedDuration => 'Gibana-bana nga oras sa biyahe';

  @override
  String get bookingBookNow => 'Mag-book Karon';

  @override
  String get bookingRequestRide => 'Pangayo og Sakyan';

  @override
  String get bookingChooseVehicle => 'Pilia ang Sakyanan';

  @override
  String get bookingSelectPayment => 'Pilia ang Pamaagi sa Pagbayad';

  @override
  String get bookingPaymentNote =>
      'Pwede ka mobayad og cash o bisan unsang digital wallet.';

  @override
  String get bookingLocationRequired =>
      'Palihug isulod ang pickup ug destinasyon.';

  @override
  String get bookingConfirmed => 'Malampuson ang booking';

  @override
  String get bookingRequestQueued =>
      'Offline ka. Na-queue ang imong ride request ug ipadala kon makakonekta ka na.';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentGcash => 'GCash';

  @override
  String get paymentMaya => 'PayMaya';

  @override
  String get paymentCard => 'Credit / Debit Card';

  @override
  String get paymentMethods => 'Pamaagi sa Pagbayad';

  @override
  String get paymentPayNow => 'Bayad Karon';

  @override
  String paymentPayFare(Object amount) {
    return 'Bayari ang $amount';
  }

  @override
  String get paymentAddCard => 'Pagdugang og Card';

  @override
  String get paymentCardNumber => 'Numero sa Card';

  @override
  String get paymentCardHolder => 'Ngalan sa Tag-iya sa Card';

  @override
  String get paymentExpiry => 'Pagkahuman';

  @override
  String get paymentCvv => 'CVV';

  @override
  String get paymentCardAdded => 'Malampuson ang pagdugang sa card';

  @override
  String get paymentGcashConfirm =>
      'I-redirect ka sa GCash aron makompleto ang pagbayad.';

  @override
  String get paymentMayaConfirm =>
      'I-redirect ka sa PayMaya aron makompleto ang pagbayad.';

  @override
  String get paymentSuccess => 'Malampuson ang Pagbayad';

  @override
  String paymentSuccessBody(Object amount) {
    return 'Naproseso na ang imong bayad nga $amount. Salamat sa pagsakay sa Sakay Ta!';
  }

  @override
  String get paymentFailed => 'Napakyas ang Pagbayad';

  @override
  String get paymentFailedBody =>
      'Palihug susiha ang imong pamaagi sa pagbayad ug sulayi usab.';

  @override
  String get paymentChoose => 'Pilia ang pamaagi sa pagbayad';

  @override
  String get paymentDriverConfirmation => 'Kompidmasiyon sa driver';

  @override
  String paymentReceivedCash(Object amount) {
    return 'Gikompirmar sa driver ang nadawat nga ₱$amount cash.';
  }

  @override
  String get paymentHistory => 'Kasaysayan sa Pagbayad';

  @override
  String paymentPaidVia(Object method) {
    return 'Gibayad pinaagi sa $method';
  }

  @override
  String get paymentReceiptTitle => 'Digital nga Resibo';

  @override
  String get paymentReceiptNo => 'Numero sa Resibo';

  @override
  String get paymentTripDate => 'Petsa sa Biyahe';

  @override
  String get paymentFareCharged => 'Fare nga Gibayad';

  @override
  String get paymentTotalPaid => 'Kinatibuk-ang Bayad';

  @override
  String get paymentThankYou => 'Salamat sa pagsakay sa Sakay Ta!';

  @override
  String get paymentReceiptSent => 'Gipadala ang resibo sa imong email';

  @override
  String get trackingTitle => 'Pagsubay sa Biyahe';

  @override
  String get trackingSearching => 'Nangita sa imong driver...';

  @override
  String get trackingAccepted => 'Nakita na ang driver!';

  @override
  String trackingAcceptedBody(Object driver) {
    return '$driver paingon na sa imong pickup.';
  }

  @override
  String get trackingArrived => 'Naabot na ang imong driver';

  @override
  String get trackingStarted => 'Paingon na sa imong destinasyon';

  @override
  String get trackingCompleted => 'Human na ang biyahe';

  @override
  String get trackingDriverOnTheWay => 'Padulong na ang imong driver';

  @override
  String get trackingEta => 'ETA';

  @override
  String get trackingMinsAway => 'KA MIN ANG NABILIN';

  @override
  String get trackingDriverInfo => 'Driver';

  @override
  String get trackingPlateNumber => 'Numero sa Plaka';

  @override
  String get trackingRating => 'Rating';

  @override
  String get trackingMessage => 'Mensahe';

  @override
  String get trackingCall => 'Tawag';

  @override
  String get trackingMaskedCall => 'Masked nga tawag';

  @override
  String get trackingShareTrip => 'I-share ang Detalye sa Biyahe';

  @override
  String trackingShareBody(
      Object driver, Object eta, Object plate, Object vehicle) {
    return 'Nagsakay ko sa Sakay Ta! $vehicle · $plate · $driver · ETA $eta ka min. Subaya ako live sa app.';
  }

  @override
  String get trackingEndTrip => 'Tapuson ang Biyahe';

  @override
  String get trackingStartRide => 'Sugdan ang Biyahe';

  @override
  String get trackingMarkArrived => 'Nakaabot Na Ko';

  @override
  String get trackingPickup => 'PICKUP';

  @override
  String get trackingDropoff => 'DROPOFF';

  @override
  String get trackingYourLocation => 'Imong lokasyon';

  @override
  String get trackingShareTitle => 'Sakay Ta — Live nga Biyahe';

  @override
  String get trackingStatusSearching => 'Nangita';

  @override
  String get trackingStatusAccepted => 'Gi-dawat';

  @override
  String get trackingStatusArrived => 'Naabot';

  @override
  String get trackingStatusStarted => 'Nagsugod';

  @override
  String get trackingStatusCompleted => 'Human';

  @override
  String trackingChatWithDriver(Object driver) {
    return 'Chat uban ni $driver';
  }

  @override
  String get trackingChatHint => 'Isulat ang mensahe...';

  @override
  String get trackingNoChats => 'Wala pa\'y mensahe. Kumusta sa imong driver!';

  @override
  String get trackingRateDriver => 'I-rate ang imong driver';

  @override
  String get trackingRateTitle => 'Unsaon man ang imong biyahe?';

  @override
  String get trackingRateSubmit => 'Isumitir ang Rating';

  @override
  String get trackingThanksFeedback => 'Salamat sa imong feedback!';

  @override
  String get trackingCancelRide => 'Kanselahon ang Ride';

  @override
  String get trackingRideCancelled => 'Gi-kanselar ang ride';

  @override
  String get ridesUpcoming => 'Moabot pa';

  @override
  String get ridesHistory => 'Kasaysayan';

  @override
  String get ridesNoUpcoming => 'Wala\'y upcoming nga rides';

  @override
  String get ridesNoUpcomingBody =>
      'Andam ka na? Pag-book og ride aron makita kini diri.';

  @override
  String get ridesNoHistory => 'Wala pa\'y biyahe';

  @override
  String get ridesNoHistoryBody =>
      'Makita diri ang imong nahuman nga mga biyahe.';

  @override
  String get ridesCompleted => 'Nahuman';

  @override
  String get ridesCancelled => 'Gi-kanselar';

  @override
  String get ridesViewDetails => 'Tan-awa ang Detalye';

  @override
  String get ridesRideHistory => 'Kasaysayan sa mga Sakyan';

  @override
  String get ridesRebook => 'Mag-book Usab';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEdit => 'Usba ang Profile';

  @override
  String get profilePaymentMethods => 'Pamaagi sa Pagbayad';

  @override
  String get profileSavedPlaces => 'Gitagong mga Lugar';

  @override
  String get profileSavedPlacesDetail => 'Balay, Trabaho';

  @override
  String get profilePreferencesSupport => 'Mga Kagustuhan ug Suporta';

  @override
  String get profileHelpCenter => 'Sentro sa Tabang';

  @override
  String get profileAccountSettings => 'Mga Setting sa Account';

  @override
  String get profileHistory => 'Kasaysayan';

  @override
  String get profileTrustedPassenger => 'Kasado nga Pasahero';

  @override
  String get profileVerifiedPassenger => 'Verified nga Pasahero';

  @override
  String get profileLanguageDetail => 'Kagustuhan sa Pinulongan';

  @override
  String get profileLanguageLabel => 'Pinulongan sa App';

  @override
  String get profileDarkMode => 'Dark Mode';

  @override
  String get profileNotifications => 'Mga Notifikasyon';

  @override
  String get profileAbout => 'Mahitungod sa Sakay Ta';

  @override
  String get profileVersion => 'Bersyon';

  @override
  String get profileTotalRides => 'Kinatibuk-ang mga Sakyan';

  @override
  String get profileJoinedSince => 'Miyembro Sukad';

  @override
  String get profilePersonalInfo => 'Personal nga Impormasyon';

  @override
  String get profileFullName => 'Tibuok Ngalan';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileMobile => 'Numero sa Selpon';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletTotalBalance => 'TIBUOK NGA MAGAMIT NGA BALANCE';

  @override
  String get walletCashEarnings => 'Cash nga Kita';

  @override
  String get walletDigitalEarnings => 'Digital (e-wallet)';

  @override
  String get walletWithdraw => 'Kuhaon';

  @override
  String get walletRecentTransactions => 'Bag-ong mga Transaksyon';

  @override
  String get walletTransactionHistory => 'Kasaysayan sa Transaksyon';

  @override
  String get walletWithdrawTo => 'Kuhaa Pinaagi sa';

  @override
  String get walletGcash => 'GCash';

  @override
  String get walletBank => 'Bank Transfer';

  @override
  String get walletEnterAmount => 'Isulod ang kantidad';

  @override
  String get walletMinMax => 'Min ₱100 · Max ₱50,000 kada transaksyon';

  @override
  String get walletWithdrawAmount => 'Kantidad nga Kuhaon';

  @override
  String get walletProcessing => 'Giproseso ang imong pagkuha...';

  @override
  String get walletSuccess => 'Malampuson ang Pagkuha';

  @override
  String walletSuccessBody(Object amount, Object method) {
    return '₱$amount gipadala na sa imong $method nga account.';
  }

  @override
  String get walletInsufficient => 'Dili igo ang balance.';

  @override
  String walletInsufficientBody(Object amount) {
    return 'Ang imong magamit nga balance ₱$amount lamang.';
  }

  @override
  String get walletNoHistory => 'Wala pa\'y transaksyon';

  @override
  String get walletFilterAll => 'Tanan';

  @override
  String get walletFilterIncoming => 'Kita';

  @override
  String get walletFilterWithdrawal => 'Pagkuha';

  @override
  String get walletDaily => 'Adlaw-adlaw';

  @override
  String get walletWeekly => 'Kada Semana';

  @override
  String get walletMonthly => 'Kada Bulan';

  @override
  String get earningsTitle => 'Kita';

  @override
  String get earningsToday => 'Karon';

  @override
  String get earningsThisWeek => 'Karon nga Semana';

  @override
  String get earningsThisMonth => 'Karon nga Bulan';

  @override
  String get earningsTotalEarnings => 'Kinatibuk-ang Kita';

  @override
  String get earningsNetEarnings => 'Kita sa Biyahe';

  @override
  String get earningsCommission => 'Kita sa Plete';

  @override
  String get earningsFare => 'Fare';

  @override
  String get earningsTrips => 'Mga Biyahe';

  @override
  String get earningsHoursOnline => 'Oras nga Online';

  @override
  String earningsTripsCount(Object count) {
    return '$count ka biyahe';
  }

  @override
  String earningsTripsAndHours(Object hours, Object trips) {
    return '$trips ka biyahe · $hours ka oras';
  }

  @override
  String get earningsTodayEarnings => 'Kita Karong Adlawa';

  @override
  String earningsUpFromYesterday(Object pct) {
    return '+$pct% kumpara kagahapon';
  }

  @override
  String earningsDownFromYesterday(Object pct) {
    return '$pct% kumpara kagahapon';
  }

  @override
  String get earningsWeeklySummary => 'Sumaryo sa Semana';

  @override
  String get earningsDailyBreakdown => 'Adlaw-adlaw nga breakdown';

  @override
  String get earningsNoEarnings => 'Wala pa\'y kita niining panahona';

  @override
  String get earningsLifetime => 'Kinatibuk-ang Kita Sukad';

  @override
  String get earningsCompletedTrips => 'Nahuman nga mga Biyahe';

  @override
  String get performanceTitle => 'Performance';

  @override
  String get performanceStats => 'Mga Estadistika sa Performance';

  @override
  String get performanceYourPerformance => 'Imong Performance';

  @override
  String get performanceRating => 'Rating';

  @override
  String get performanceAcceptance => 'Pagdawat';

  @override
  String get performanceAcceptanceRate => 'Rate sa Pagdawat';

  @override
  String get performanceAccuracy => 'Katukma';

  @override
  String get performanceAccuracyRate => 'Pagsaabot sa Oras';

  @override
  String get performanceCancellation => 'Kanselasyon';

  @override
  String get performanceTotalTrips => 'Kinatibuk-ang mga Biyahe';

  @override
  String get performanceLifetimeEarnings => 'Kinatibuk-ang Kita Sukad';

  @override
  String get performanceWeeklyComparison => 'Pagkumpara sa Semana';

  @override
  String get performanceLastWeek => 'Niaging Semana';

  @override
  String get performanceCurrentWeek => 'Karon nga Semana';

  @override
  String get performanceTripsEarnings => 'Mga Biyahe ug Kita';

  @override
  String get performanceFeedback => 'Feedback sa Pasahero';

  @override
  String get performanceSeeAll => 'Tan-awa ang Tanan';

  @override
  String get performanceTopTier => 'Top Tier';

  @override
  String get performanceAverage => 'Kasarangan';

  @override
  String get performanceExcellent => 'Maayo Kaayo';

  @override
  String get performanceLow => 'Ubos';

  @override
  String get performanceBadges => 'Mga Badge ug Nakab-ot';

  @override
  String get performanceAchievement1 => 'Road Warrior';

  @override
  String get performanceAchievement1Desc => '100 ka biyahe nahuman';

  @override
  String get performanceAchievement2 => 'Early Bird';

  @override
  String get performanceAchievement2Desc => 'Unang biyahe sa dili pa 7 AM';

  @override
  String get performanceAchievement3 => 'Star Rider';

  @override
  String get performanceAchievement3Desc => '5.0 nga average nga rating';

  @override
  String get performanceAchievement4 => 'Weekend Hero';

  @override
  String get performanceAchievement4Desc => '20 ka biyahe sa usa ka weekend';

  @override
  String get performanceAchievement5 => 'Safe Driver';

  @override
  String get performanceAchievement5Desc => '100 ka biyahe nga walay reklamo';

  @override
  String get performanceLocked => 'Naka-lock';

  @override
  String performanceTierLabel(Object tier) {
    return 'Tier: $tier';
  }

  @override
  String get performanceLguCompliance => 'Pag-uyon sa LGU';

  @override
  String get performanceLguActive => 'Aktibo ug verified';

  @override
  String get adminTitle => 'Admin Dashboard';

  @override
  String get adminDrivers => 'Mga Driver';

  @override
  String get adminPassengers => 'Mga Pasahero';

  @override
  String get adminTotalTrips => 'Kinatibuk-ang mga Biyahe';

  @override
  String get adminTotalRevenue => 'Kita sa Platform';

  @override
  String get adminPendingReviews => 'Pending nga mga Review';

  @override
  String get adminApprovedDrivers => 'Gi-aprubahan nga mga Driver';

  @override
  String get adminRejectedDrivers => 'Gibali-barahan nga mga Driver';

  @override
  String get adminApprove => 'Aprubahan';

  @override
  String get adminReject => 'Balibaran';

  @override
  String get adminRejectReason => 'Rason sa pagbalibad (opsyonal)';

  @override
  String get adminRejectPrompt =>
      'Balibaran kini nga driver? Pahibalo-on sila sa imong rason.';

  @override
  String get adminApprovePrompt =>
      'Aprubahan kini nga driver? Makaka-online dayon sila.';

  @override
  String get adminDriverApproved => 'Gi-aprubahan ang driver';

  @override
  String get adminDriverRejected => 'Gibali-barahan ang driver';

  @override
  String get adminViewDetails => 'Tan-awa ang Detalye';

  @override
  String get adminManageDrivers => 'Dumala ang mga Driver';

  @override
  String get adminDriverId => 'ID sa Driver';

  @override
  String get adminSubmittedAt => 'Gi-submit';

  @override
  String get adminTodaReports => 'Mga Report sa TODA';

  @override
  String get adminTodaTitle => 'Pagdumala sa TODA';

  @override
  String get adminAddToda => 'Pagdugang og TODA';

  @override
  String get adminEditToda => 'Usba ang TODA';

  @override
  String get adminDeleteToda => 'Papason ang TODA';

  @override
  String get adminTodaName => 'Ngalan sa TODA';

  @override
  String get adminTodaLeader => 'Ngalan sa Lider';

  @override
  String get adminTodaContact => 'Numero sa Kontak';

  @override
  String get adminTodaArea => 'Lugar nga Gisilbihan';

  @override
  String get adminTodaMembers => 'Mga Miyembro';

  @override
  String get adminDeleteTodaConfirm => 'Papason kini nga TODA?';

  @override
  String get adminTodaAdded => 'Nadugang ang TODA';

  @override
  String get adminTodaUpdated => 'Na-update ang TODA';

  @override
  String get adminTodaDeleted => 'Napapas ang TODA';

  @override
  String get adminLguPartnerships => 'Pakigtambayayong sa LGU';

  @override
  String get adminAddPartnership => 'Pagdugang og Pakigtambayayong';

  @override
  String get adminPartnershipName => 'LGU / Munisipalidad';

  @override
  String get adminPartnershipActive => 'Aktibo';

  @override
  String get adminPartnershipInactive => 'Dili Aktibo';

  @override
  String get adminReports => 'Mga Report';

  @override
  String get adminReportsByToda => 'Mga Report per TODA';

  @override
  String get adminDriverCount => 'Mga Driver';

  @override
  String get adminTripCount => 'Mga Biyahe';

  @override
  String get adminRevenue => 'Kita';

  @override
  String get adminAvgRating => 'Average nga Rating';

  @override
  String get adminExport => 'I-export ang Report';

  @override
  String get adminExported => 'Na-export ang report';

  @override
  String get offlineTitle => 'Offline ka';

  @override
  String get offlineBody =>
      'Offline ka karon. Gipakita ang naka-cache nga datos.';

  @override
  String get offlineReconnecting => 'Nag-reconnect...';

  @override
  String get offlineBackOnline => 'Balik online';

  @override
  String offlineQueuedRequests(Object count) {
    return 'Naka-queue nga requests: $count';
  }

  @override
  String get offlineSyncing => 'Giproseso ang imong naka-queue nga requests...';

  @override
  String get offlineSynced => 'Ang tanang naka-queue nga requests na-sync na';

  @override
  String get offlineCached => 'Naka-cache nga datos';

  @override
  String get offlineWaiting => 'Naghulat og koneksyon...';

  @override
  String get mapLabel => 'Mapa';

  @override
  String get mapOfflineNotice => 'Gipakita ang naka-cache nga mapa';

  @override
  String get notifRideRequest => 'Bag-ong ride request';

  @override
  String get notifPaymentReceived => 'Nadawat ang bayad';

  @override
  String get notifAccountApproved => 'Gi-aprubahan na ang imong account!';

  @override
  String get notifAccountRejected => 'Gibali-barahan ang imong account';

  @override
  String get notifDriverArrived => 'Naabot ang driver';

  @override
  String get notifTripCompleted => 'Human na ang biyahe';

  @override
  String notifChat(Object name) {
    return 'Bag-ong mensahe ni $name';
  }

  @override
  String get notifTitle => 'Mga Notifikasyon';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatYou => 'Ikaw';

  @override
  String get chatDriver => 'Driver';

  @override
  String get chatTypeMessage => 'Isulat ang mensahe...';

  @override
  String get chatSend => 'Ipadala';

  @override
  String get chatNoMessages => 'Wala pa\'y mensahe';

  @override
  String get langEn => 'English';

  @override
  String get langCeb => 'Cebuano';

  @override
  String get langTl => 'Tagalog';

  @override
  String get langAppLanguage => 'Pinulongan sa App';

  @override
  String get langChanged => 'Nabag-o ang pinulongan';

  @override
  String get signUpPassengerTitle => 'Pag-rehistro isip Pasahero';

  @override
  String get signUpPassengerSubtitle =>
      'Mag-rehistro aron makasugod sa pag-book sa imong mga sakay.';

  @override
  String get signUpFullName => 'Punoan nga Pangalan';

  @override
  String get signUpFullNameHint => 'mga. Juan Dela Cruz';

  @override
  String get signUpFullNameError =>
      'Palihug ibutang ang imong punoan nga pangalan (labing mubo 2 ka letra).';

  @override
  String get signUpMobileNumber => 'Numero sa Telepono';

  @override
  String get signUpMobileHint => '09XX XXX XXXX';

  @override
  String get signUpMobileError =>
      'Palihug ibutang ang sakto nga 11-digit nga numero sa telepono.';

  @override
  String get signUpPassword => 'Kontrasañas';

  @override
  String get signUpPasswordHint => 'Labing mubo 6 ka karakter';

  @override
  String get signUpPasswordError =>
      'Ang kontrasañas kinahanglan labing mubo 6 ka karakter.';

  @override
  String get signUpConfirmPassword => 'Kumpirmaha ang Kontrasañas';

  @override
  String get signUpConfirmPasswordHint => 'I-utro pag-input ang kontrasañas';

  @override
  String get signUpConfirmPasswordError =>
      'Dili magkaparehas ang mga kontrasañas.';

  @override
  String get signUpTermsText =>
      'Miuyon ako sa Mga Termino ug Kondisyon ug Palisiya sa Pribasiya';

  @override
  String get signUpTermsRequired =>
      'Kinahanglan kang mouyon sa Mga Termino ug Kondisyon aron magpadayon.';

  @override
  String get signUpButton => 'Pag-rehistro';

  @override
  String get signUpAlreadyHaveAccount => 'Naa na kay account? ';

  @override
  String get signUpLoginLink => 'Mo-login';

  @override
  String get signUpPreferredLanguage => 'Gipili nga Pinulongan';

  @override
  String get navHome => 'Balay';

  @override
  String get navActivity => 'Kalihokan';

  @override
  String get navWallet => 'Pitaka';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileClearCache => 'Hawani ang Cache';

  @override
  String get profileClearCacheSubtitle =>
      'Hawani ang temporaryong files ug cache sa mapa';

  @override
  String profileClearCacheSuccess(Object size) {
    return 'Malampusong nahawan ang cache! ($size ang nahawanan)';
  }

  @override
  String get profileClearCacheConfirm =>
      'Hawani ang temporaryong cache? Magpabilin nga luwas ang imong account ug kasaysayan sa biyahe.';

  @override
  String get profileLogoutTitle => 'Mo-log Out';

  @override
  String get profileLogoutSubtitle => 'Mo-sign out niining device';

  @override
  String get profileLogoutMessage =>
      'Sigurado ka ba nga gusto kang mo-log out? Ang imong account ug kasaysayan sa biyahe luwas nga gitipigan sa server.';

  @override
  String get profileLogoutButton => 'Mo-log Out';

  @override
  String get profileDeleteAccountTitle => 'Papasa ang Account';

  @override
  String get profileDeleteAccountSubtitle =>
      'Permanenteng papasa ang imong account ug datos sa server';

  @override
  String get profileDeleteAccountWarning =>
      'Sigurado ka ba nga gusto nimong papason sa permanente ang imong Sakay Ta account? Dili na kini mabalik ug permanenteng mawala ang imong profile, kasaysayan sa biyahe, ug gitipigang datos gikan sa among mga server.';

  @override
  String get profileDeleteAccountConfirmButton => 'Permanenteng Papasa';

  @override
  String get profileDeleteAccountSuccess =>
      'Malampusong napapas ang imong account.';

  @override
  String get profileSelectLanguage => 'Pilia ang Pinulongan';

  @override
  String get profileBisayaLanguage => 'Bisaya (Binisaya / Cebuano)';

  @override
  String get profileEnglishLanguage => 'English (US / PH)';

  @override
  String get profileTagalogLanguage => 'Tagalog (Filipino)';

  @override
  String get profileDangerZone => 'Delikado nga Sona';

  @override
  String get homeGreetingMorning => 'Maayong Buntag!';

  @override
  String get homeGreetingAfternoon => 'Maayong Hapon!';

  @override
  String get homeGreetingEvening => 'Maayong Gabii!';

  @override
  String get homeWhereTo => 'Asa ka padulong?';

  @override
  String get homeSearchDestination => 'Pangitaa ang destinasyon...';

  @override
  String get homeQuickDestinations => 'Daling Padulngan';

  @override
  String get homeRecentActivity => 'Bag-ong Kalihokan';

  @override
  String get homeNearbyDrivers => 'Mga Drayber sa Duol';

  @override
  String get homeNoNearbyDrivers =>
      'Walay aktibong drayber sa imong lugar karon.';

  @override
  String get homeBookRide => 'Pag-book og Biyahe';

  @override
  String get homeCurrentLocation => 'Karon nga Lokasyon';

  @override
  String get homePopularPlaces => 'Mga Iladong Lugar';

  @override
  String get walletCashIn => 'Pag-top Up';

  @override
  String get walletSendMoney => 'Pagbalhin';

  @override
  String get walletAddPaymentMethod => 'Dugangi og Paagi sa Pagbayad';

  @override
  String get walletLinkedAccounts => 'Gikonektar nga mga Account';

  @override
  String get walletDefaultPayment => 'Panguna nga Pagbayad';

  @override
  String get walletManagePayments => 'Dumalaha ang mga Paagi sa Pagbayad';

  @override
  String get walletSavedAccounts => 'Na-save nga mga Account';

  @override
  String get walletHistoryReceipts => 'Kasaysayan sa Pagbayad ug Resibo';

  @override
  String get walletNoRecords => 'Wala pay mga rekord sa pagbayad.';

  @override
  String get ridesEmptyUpcoming => 'Walay umaabot nga biyahe';

  @override
  String get ridesEmptyUpcomingSubtitle =>
      'Andam na mobiyahe? Pag-book og sakay aron makita kini dinhi.';

  @override
  String get ridesEmptyCompleted => 'Wala pay nahuman nga biyahe';

  @override
  String get ridesEmptyCompletedSubtitle =>
      'Ang imong mga resibo ug kasaysayan sa nahuman nga biyahe makita dinhi.';

  @override
  String get ridesEmptyCancelled => 'Walay gikanselar nga biyahe';

  @override
  String get ridesEmptyCancelledSubtitle =>
      'Ang mga nakanselar nga biyahe makita dinhi.';

  @override
  String get ridesBookNow => 'Pag-book og Sakay Karon';
}
