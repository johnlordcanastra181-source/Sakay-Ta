// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Sakay Ta';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonDone => 'Done';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonViewAll => 'View All';

  @override
  String get commonAll => 'All';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonLogout => 'Log out';

  @override
  String get commonLanguage => 'Language';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonNotAvailable => 'Not available';

  @override
  String get commonNoData => 'No data available';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOptional => '(optional)';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonUpload => 'Upload';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonEmpty => 'Nothing here yet';

  @override
  String get rolePassenger => 'Passenger';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginGreeting => 'Good Morning!';

  @override
  String get loginSubtitlePassenger => 'Login to start riding.';

  @override
  String get loginSubtitleDriver => 'Login to start earning.';

  @override
  String get loginSubtitleAdmin => 'Login to manage Sakay Ta.';

  @override
  String get loginMobileNumber => 'Mobile Number';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginMobileHint => '+63 9XX XXX XXXX';

  @override
  String get loginForgotPassword => 'Forgot Password?';

  @override
  String get loginLoginButton => 'Log In';

  @override
  String get loginNoAccount => 'Don\'t have an account? Create one now';

  @override
  String get loginLanguageLabel => 'Language';

  @override
  String get loginDemoAccounts => 'Demo Accounts';

  @override
  String get loginDemoPassenger => 'Passenger Demo';

  @override
  String get loginDemoDriver => 'Driver Demo';

  @override
  String get loginDemoAdmin => 'Admin Demo';

  @override
  String get loginPhoneRequired => 'Please enter your mobile number.';

  @override
  String get loginPasswordRequired => 'Please enter your password.';

  @override
  String get loginInvalidCredentials => 'Invalid mobile number or password.';

  @override
  String get loginAccountPending => 'Your account is still under review.';

  @override
  String loginAccountRejected(Object reason) {
    return 'Your account was rejected: $reason';
  }

  @override
  String loginWrongRole(Object role) {
    return 'No $role account found for this number.';
  }

  @override
  String get loginLogoutConfirm => 'Are you sure you want to log out?';

  @override
  String get driverStatus => 'Status';

  @override
  String get driverStatusPending => 'Pending';

  @override
  String get driverStatusApproved => 'Approved';

  @override
  String get driverStatusRejected => 'Rejected';

  @override
  String get driverPendingApproval => 'Pending Approval';

  @override
  String get driverPendingNote =>
      'Your documents are being verified by our team. This usually takes 24-48 hours.';

  @override
  String get driverVerifiedBadge => 'Verified';

  @override
  String get driverVerifiedDriver => 'Verified Driver';

  @override
  String get driverUnverified => 'Not verified';

  @override
  String driverRejectionReason(Object reason) {
    return 'Rejection reason: $reason';
  }

  @override
  String get driverOnlineRestricted =>
      'You can only go online after your application is approved.';

  @override
  String get driverVerificationStatus => 'Verification Status';

  @override
  String get driverDocumentsApproved => 'Documents Approved';

  @override
  String get regTitle => 'Become a Driver';

  @override
  String get regSubtitle => 'Earn on your own schedule';

  @override
  String get regStep1 => 'Personal';

  @override
  String get regStep2 => 'License';

  @override
  String get regStep3 => 'Vehicle';

  @override
  String get regStep4 => 'Association';

  @override
  String get regStep5 => 'Documents';

  @override
  String get regFullName => 'Full Name';

  @override
  String get regFullNameHint => 'John Dela Cruz';

  @override
  String get regMobileNumber => 'Mobile Number';

  @override
  String get regMobileHint => '+63 912 345 6789';

  @override
  String get regPassword => 'Password';

  @override
  String get regPasswordHint => 'At least 8 characters';

  @override
  String get regDateOfBirth => 'Date of Birth';

  @override
  String get regSex => 'Sex';

  @override
  String get regMale => 'Male';

  @override
  String get regFemale => 'Female';

  @override
  String get regAddress => 'Current Address';

  @override
  String get regAddressHint => 'Block, Lot, Street, Barangay, City...';

  @override
  String get regLicenseType => 'License Type';

  @override
  String get regNonProfessional => 'Non-Professional';

  @override
  String get regProfessional => 'Professional';

  @override
  String get regLicenseNumber => 'License Number';

  @override
  String get regLicenseNumberHint => 'N01-12-345678';

  @override
  String get regLicenseExpiry => 'License Expiry Date';

  @override
  String get regDlCodes => 'DL Codes';

  @override
  String get regConditionCodes => 'Condition Codes';

  @override
  String get regVehicleType => 'Vehicle Type';

  @override
  String get regPlateNumber => 'Plate Number';

  @override
  String get regMake => 'Make';

  @override
  String get regModel => 'Model';

  @override
  String get regYear => 'Year';

  @override
  String get regColor => 'Color';

  @override
  String get regToda => 'TODA Association';

  @override
  String get regTodaHint => 'Select your TODA';

  @override
  String get regTodaNotListed => 'My TODA is not listed';

  @override
  String get regBarangay => 'Barangay';

  @override
  String get regMunicipality => 'Municipality';

  @override
  String get regProvince => 'Province';

  @override
  String get regDocLicenseFront => 'License Photo (Front)';

  @override
  String get regDocLicenseBack => 'License Photo (Back)';

  @override
  String get regDocOrCr => 'OR/CR Photo';

  @override
  String get regDocProfile => 'Profile Photo';

  @override
  String get regUploadTap => 'Tap to upload';

  @override
  String get regUploaded => 'Uploaded';

  @override
  String get regSubmitApplication => 'Submit Application';

  @override
  String regNextStep(Object step) {
    return 'Next: $step';
  }

  @override
  String get regPrevStep => 'Previous';

  @override
  String get regApplicationSubmitted => 'Application Submitted!';

  @override
  String get regApplicationSubmittedBody =>
      'Thank you! Your application is now pending review. We will notify you once your account is verified.';

  @override
  String get regBackToLogin => 'Back to Login';

  @override
  String get regFillRequired => 'Please fill in all required fields.';

  @override
  String get regPasswordTooShort => 'Password must be at least 8 characters.';

  @override
  String get regUploadAllDocs => 'Please upload all required documents.';

  @override
  String get regSuccessTitle => 'Welcome aboard!';

  @override
  String get regSuccessBody =>
      'Your application has been received. An admin will review your documents within 24-48 hours.';

  @override
  String get vehicleTricycle => 'Tricycle';

  @override
  String get vehicleHabal => 'Habal-Habal';

  @override
  String get vehicleTricycleSub => '3-4 pax';

  @override
  String get vehicleHabalSub => '1-2 pax';

  @override
  String get vehicleStartsAt => 'Starts at';

  @override
  String get vehicleMinsAway => 'mins away';

  @override
  String vehicleAvailable(Object count) {
    return '$count available nearby';
  }

  @override
  String get vehicleChooseType => 'Choose your ride';

  @override
  String get vehicleBaseFare => 'Base Fare';

  @override
  String get vehiclePerKm => 'Per km';

  @override
  String get bookingPickup => 'Pickup location';

  @override
  String get bookingDropoff => 'Drop-off location';

  @override
  String get bookingEnterPickup => 'Enter pickup location';

  @override
  String get bookingEnterDropoff => 'Enter destination';

  @override
  String get bookingUseCurrentLocation => 'Use current location';

  @override
  String get bookingSearchingDrivers => 'Searching for drivers...';

  @override
  String bookingSearchingBody(Object vehicle) {
    return 'We are finding the nearest $vehicle for you.';
  }

  @override
  String get bookingCancelBooking => 'Cancel Booking';

  @override
  String get bookingCancelConfirm => 'Cancel this ride request?';

  @override
  String get bookingEstimatedFare => 'Estimated Fare';

  @override
  String get bookingEstimatedDistance => 'Estimated distance';

  @override
  String get bookingEstimatedDuration => 'Estimated travel time';

  @override
  String get bookingBookNow => 'Book Now';

  @override
  String get bookingRequestRide => 'Request Ride';

  @override
  String get bookingChooseVehicle => 'Select Vehicle';

  @override
  String get bookingSelectPayment => 'Select Payment Method';

  @override
  String get bookingPaymentNote =>
      'You can pay with cash or any digital wallet.';

  @override
  String get bookingLocationRequired =>
      'Please set your pickup and destination.';

  @override
  String get bookingConfirmed => 'Ride booked successfully';

  @override
  String get bookingRequestQueued =>
      'You are offline. Your ride request is queued and will be sent when you reconnect.';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentGcash => 'GCash';

  @override
  String get paymentMaya => 'PayMaya';

  @override
  String get paymentCard => 'Credit / Debit Card';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get paymentPayNow => 'Pay Now';

  @override
  String paymentPayFare(Object amount) {
    return 'Pay $amount';
  }

  @override
  String get paymentAddCard => 'Add New Card';

  @override
  String get paymentCardNumber => 'Card Number';

  @override
  String get paymentCardHolder => 'Cardholder Name';

  @override
  String get paymentExpiry => 'Expiry';

  @override
  String get paymentCvv => 'CVV';

  @override
  String get paymentCardAdded => 'Card added successfully';

  @override
  String get paymentGcashConfirm =>
      'You will be redirected to GCash to complete the payment.';

  @override
  String get paymentMayaConfirm =>
      'You will be redirected to PayMaya to complete the payment.';

  @override
  String get paymentSuccess => 'Payment Successful';

  @override
  String paymentSuccessBody(Object amount) {
    return 'Your payment of $amount was processed. Thank you for riding with Sakay Ta!';
  }

  @override
  String get paymentFailed => 'Payment Failed';

  @override
  String get paymentFailedBody =>
      'Please check your payment method and try again.';

  @override
  String get paymentChoose => 'Choose payment method';

  @override
  String get paymentDriverConfirmation => 'Driver payment confirmation';

  @override
  String paymentReceivedCash(Object amount) {
    return 'Driver confirmed receipt of ₱$amount cash.';
  }

  @override
  String get paymentHistory => 'Payment History';

  @override
  String paymentPaidVia(Object method) {
    return 'Paid via $method';
  }

  @override
  String get paymentReceiptTitle => 'Digital Receipt';

  @override
  String get paymentReceiptNo => 'Receipt No.';

  @override
  String get paymentTripDate => 'Trip Date';

  @override
  String get paymentFareCharged => 'Fare Charged';

  @override
  String get paymentTotalPaid => 'Total Paid';

  @override
  String get paymentThankYou => 'Thank you for riding Sakay Ta!';

  @override
  String get paymentReceiptSent => 'Receipt sent to your email';

  @override
  String get trackingTitle => 'Trip Tracking';

  @override
  String get trackingSearching => 'Searching for your driver...';

  @override
  String get trackingAccepted => 'Driver found!';

  @override
  String trackingAcceptedBody(Object driver) {
    return '$driver is heading to your pickup.';
  }

  @override
  String get trackingArrived => 'Your driver has arrived';

  @override
  String get trackingStarted => 'On the way to your destination';

  @override
  String get trackingCompleted => 'Trip completed';

  @override
  String get trackingDriverOnTheWay => 'Your driver is on the way';

  @override
  String get trackingEta => 'ETA';

  @override
  String get trackingMinsAway => 'MINS AWAY';

  @override
  String get trackingDriverInfo => 'Driver';

  @override
  String get trackingPlateNumber => 'Plate Number';

  @override
  String get trackingRating => 'Rating';

  @override
  String get trackingMessage => 'Message';

  @override
  String get trackingCall => 'Call';

  @override
  String get trackingMaskedCall => 'Masked call';

  @override
  String get trackingShareTrip => 'Share Trip Details';

  @override
  String trackingShareBody(
      Object driver, Object eta, Object plate, Object vehicle) {
    return 'I\'m riding with Sakay Ta! $vehicle · $plate · $driver · ETA $eta mins. Track me live in the app.';
  }

  @override
  String get trackingEndTrip => 'End Trip';

  @override
  String get trackingStartRide => 'Start Ride';

  @override
  String get trackingMarkArrived => 'I\'ve Arrived';

  @override
  String get trackingPickup => 'PICKUP';

  @override
  String get trackingDropoff => 'DROPOFF';

  @override
  String get trackingYourLocation => 'Your location';

  @override
  String get trackingShareTitle => 'Sakay Ta — Live Trip';

  @override
  String get trackingStatusSearching => 'Searching';

  @override
  String get trackingStatusAccepted => 'Accepted';

  @override
  String get trackingStatusArrived => 'Arrived';

  @override
  String get trackingStatusStarted => 'Started';

  @override
  String get trackingStatusCompleted => 'Completed';

  @override
  String trackingChatWithDriver(Object driver) {
    return 'Chat with $driver';
  }

  @override
  String get trackingChatHint => 'Type a message...';

  @override
  String get trackingNoChats => 'No messages yet. Say hi to your driver!';

  @override
  String get trackingRateDriver => 'Rate your driver';

  @override
  String get trackingRateTitle => 'How was your ride?';

  @override
  String get trackingRateSubmit => 'Submit Rating';

  @override
  String get trackingThanksFeedback => 'Thanks for your feedback!';

  @override
  String get trackingCancelRide => 'Cancel Ride';

  @override
  String get trackingRideCancelled => 'Ride cancelled';

  @override
  String get ridesUpcoming => 'Upcoming';

  @override
  String get ridesHistory => 'History';

  @override
  String get ridesNoUpcoming => 'No upcoming rides';

  @override
  String get ridesNoUpcomingBody => 'Ready to go? Book a ride to see it here.';

  @override
  String get ridesNoHistory => 'No trips yet';

  @override
  String get ridesNoHistoryBody => 'Your completed trips will appear here.';

  @override
  String get ridesCompleted => 'Completed';

  @override
  String get ridesCancelled => 'Cancelled';

  @override
  String get ridesViewDetails => 'View Details';

  @override
  String get ridesRideHistory => 'Ride History';

  @override
  String get ridesRebook => 'Rebook';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEdit => 'Edit Profile';

  @override
  String get profilePaymentMethods => 'Payment Methods';

  @override
  String get profileSavedPlaces => 'Saved Places';

  @override
  String get profileSavedPlacesDetail => 'Home, Work';

  @override
  String get profilePreferencesSupport => 'Preferences & Support';

  @override
  String get profileHelpCenter => 'Help Center';

  @override
  String get profileAccountSettings => 'Account Settings';

  @override
  String get profileHistory => 'History';

  @override
  String get profileTrustedPassenger => 'Trusted Passenger';

  @override
  String get profileVerifiedPassenger => 'Verified Passenger';

  @override
  String get profileLanguageDetail => 'Language Preference';

  @override
  String get profileLanguageLabel => 'App Language';

  @override
  String get profileDarkMode => 'Dark Mode';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileAbout => 'About Sakay Ta';

  @override
  String get profileVersion => 'Version';

  @override
  String get profileTotalRides => 'Total Rides';

  @override
  String get profileJoinedSince => 'Joined Since';

  @override
  String get profilePersonalInfo => 'Personal Information';

  @override
  String get profileFullName => 'Full Name';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileMobile => 'Mobile Number';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletTotalBalance => 'TOTAL AVAILABLE BALANCE';

  @override
  String get walletCashEarnings => 'Cash Earnings';

  @override
  String get walletDigitalEarnings => 'Digital (e-wallet)';

  @override
  String get walletWithdraw => 'Withdraw';

  @override
  String get walletRecentTransactions => 'Recent Transactions';

  @override
  String get walletTransactionHistory => 'Transaction History';

  @override
  String get walletWithdrawTo => 'Withdraw To';

  @override
  String get walletGcash => 'GCash';

  @override
  String get walletBank => 'Bank Transfer';

  @override
  String get walletEnterAmount => 'Enter amount';

  @override
  String get walletMinMax => 'Min ₱100 · Max ₱50,000 per transaction';

  @override
  String get walletWithdrawAmount => 'Withdrawal Amount';

  @override
  String get walletProcessing => 'Processing your withdrawal...';

  @override
  String get walletSuccess => 'Withdrawal Successful';

  @override
  String walletSuccessBody(Object amount, Object method) {
    return '₱$amount has been sent to your $method account.';
  }

  @override
  String get walletInsufficient => 'Insufficient balance.';

  @override
  String walletInsufficientBody(Object amount) {
    return 'Your available balance is only ₱$amount.';
  }

  @override
  String get walletNoHistory => 'No transactions yet';

  @override
  String get walletFilterAll => 'All';

  @override
  String get walletFilterIncoming => 'Income';

  @override
  String get walletFilterWithdrawal => 'Withdrawals';

  @override
  String get walletDaily => 'Daily';

  @override
  String get walletWeekly => 'Weekly';

  @override
  String get walletMonthly => 'Monthly';

  @override
  String get earningsTitle => 'Earnings';

  @override
  String get earningsToday => 'Today';

  @override
  String get earningsThisWeek => 'This Week';

  @override
  String get earningsThisMonth => 'This Month';

  @override
  String get earningsTotalEarnings => 'Total Earnings';

  @override
  String get earningsNetEarnings => 'Ride Earnings';

  @override
  String get earningsCommission => 'Fare Earnings';

  @override
  String get earningsFare => 'Fare';

  @override
  String get earningsTrips => 'Trips';

  @override
  String get earningsHoursOnline => 'Hours Online';

  @override
  String earningsTripsCount(Object count) {
    return '$count trips';
  }

  @override
  String earningsTripsAndHours(Object hours, Object trips) {
    return '$trips trips · $hours hours';
  }

  @override
  String get earningsTodayEarnings => 'Today\'s Earnings';

  @override
  String earningsUpFromYesterday(Object pct) {
    return '+$pct% from yesterday';
  }

  @override
  String earningsDownFromYesterday(Object pct) {
    return '$pct% from yesterday';
  }

  @override
  String get earningsWeeklySummary => 'Weekly Summary';

  @override
  String get earningsDailyBreakdown => 'Daily breakdown';

  @override
  String get earningsNoEarnings => 'No earnings yet this period';

  @override
  String get earningsLifetime => 'Lifetime Earnings';

  @override
  String get earningsCompletedTrips => 'Completed Trips';

  @override
  String get performanceTitle => 'Performance';

  @override
  String get performanceStats => 'Performance Stats';

  @override
  String get performanceYourPerformance => 'Your Performance';

  @override
  String get performanceRating => 'Rating';

  @override
  String get performanceAcceptance => 'Acceptance';

  @override
  String get performanceAcceptanceRate => 'Acceptance Rate';

  @override
  String get performanceAccuracy => 'Accuracy';

  @override
  String get performanceAccuracyRate => 'On-time Arrival';

  @override
  String get performanceCancellation => 'Cancellation';

  @override
  String get performanceTotalTrips => 'Total Trips';

  @override
  String get performanceLifetimeEarnings => 'Lifetime Earnings';

  @override
  String get performanceWeeklyComparison => 'Weekly Comparison';

  @override
  String get performanceLastWeek => 'Last Week';

  @override
  String get performanceCurrentWeek => 'This Week';

  @override
  String get performanceTripsEarnings => 'Trips & Earnings';

  @override
  String get performanceFeedback => 'Passenger Feedback';

  @override
  String get performanceSeeAll => 'See all';

  @override
  String get performanceTopTier => 'Top Tier';

  @override
  String get performanceAverage => 'Average';

  @override
  String get performanceExcellent => 'Excellent';

  @override
  String get performanceLow => 'Low';

  @override
  String get performanceBadges => 'Badges & Achievements';

  @override
  String get performanceAchievement1 => 'Road Warrior';

  @override
  String get performanceAchievement1Desc => '100 trips completed';

  @override
  String get performanceAchievement2 => 'Early Bird';

  @override
  String get performanceAchievement2Desc => 'First trip before 7 AM';

  @override
  String get performanceAchievement3 => 'Star Rider';

  @override
  String get performanceAchievement3Desc => '5.0 average rating';

  @override
  String get performanceAchievement4 => 'Weekend Hero';

  @override
  String get performanceAchievement4Desc => '20 trips in one weekend';

  @override
  String get performanceAchievement5 => 'Safe Driver';

  @override
  String get performanceAchievement5Desc => '100 trips with zero complaints';

  @override
  String get performanceLocked => 'Locked';

  @override
  String performanceTierLabel(Object tier) {
    return 'Tier: $tier';
  }

  @override
  String get performanceLguCompliance => 'LGU Compliance';

  @override
  String get performanceLguActive => 'Active & verified';

  @override
  String get adminTitle => 'Admin Dashboard';

  @override
  String get adminDrivers => 'Drivers';

  @override
  String get adminPassengers => 'Passengers';

  @override
  String get adminTotalTrips => 'Total Trips';

  @override
  String get adminTotalRevenue => 'Platform Revenue';

  @override
  String get adminPendingReviews => 'Pending Reviews';

  @override
  String get adminApprovedDrivers => 'Approved Drivers';

  @override
  String get adminRejectedDrivers => 'Rejected Drivers';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminRejectReason => 'Reason for rejection (optional)';

  @override
  String get adminRejectPrompt =>
      'Reject this driver? They will be notified with your reason.';

  @override
  String get adminApprovePrompt =>
      'Approve this driver? They will be able to go online immediately.';

  @override
  String get adminDriverApproved => 'Driver approved';

  @override
  String get adminDriverRejected => 'Driver rejected';

  @override
  String get adminViewDetails => 'View Details';

  @override
  String get adminManageDrivers => 'Manage Drivers';

  @override
  String get adminDriverId => 'Driver ID';

  @override
  String get adminSubmittedAt => 'Submitted';

  @override
  String get adminTodaReports => 'TODA Reports';

  @override
  String get adminTodaTitle => 'TODA Management';

  @override
  String get adminAddToda => 'Add TODA';

  @override
  String get adminEditToda => 'Edit TODA';

  @override
  String get adminDeleteToda => 'Delete TODA';

  @override
  String get adminTodaName => 'TODA Name';

  @override
  String get adminTodaLeader => 'Leader Name';

  @override
  String get adminTodaContact => 'Contact Number';

  @override
  String get adminTodaArea => 'Service Area';

  @override
  String get adminTodaMembers => 'Members';

  @override
  String get adminDeleteTodaConfirm => 'Delete this TODA?';

  @override
  String get adminTodaAdded => 'TODA added';

  @override
  String get adminTodaUpdated => 'TODA updated';

  @override
  String get adminTodaDeleted => 'TODA deleted';

  @override
  String get adminLguPartnerships => 'LGU Partnerships';

  @override
  String get adminAddPartnership => 'Add Partnership';

  @override
  String get adminPartnershipName => 'LGU / Municipality';

  @override
  String get adminPartnershipActive => 'Active';

  @override
  String get adminPartnershipInactive => 'Inactive';

  @override
  String get adminReports => 'Reports';

  @override
  String get adminReportsByToda => 'Reports by TODA';

  @override
  String get adminDriverCount => 'Drivers';

  @override
  String get adminTripCount => 'Trips';

  @override
  String get adminRevenue => 'Revenue';

  @override
  String get adminAvgRating => 'Avg Rating';

  @override
  String get adminExport => 'Export Report';

  @override
  String get adminExported => 'Report exported';

  @override
  String get offlineTitle => 'You are offline';

  @override
  String get offlineBody => 'You\'re currently offline. Showing cached data.';

  @override
  String get offlineReconnecting => 'Reconnecting...';

  @override
  String get offlineBackOnline => 'Back online';

  @override
  String offlineQueuedRequests(Object count) {
    return 'Queued requests: $count';
  }

  @override
  String get offlineSyncing => 'Syncing your queued requests...';

  @override
  String get offlineSynced => 'All queued requests synced';

  @override
  String get offlineCached => 'Cached data';

  @override
  String get offlineWaiting => 'Waiting for connection...';

  @override
  String get mapLabel => 'Map';

  @override
  String get mapOfflineNotice => 'Showing cached map tiles';

  @override
  String get notifRideRequest => 'New ride request';

  @override
  String get notifPaymentReceived => 'Payment received';

  @override
  String get notifAccountApproved => 'Your account has been approved!';

  @override
  String get notifAccountRejected => 'Your account was rejected';

  @override
  String get notifDriverArrived => 'Driver arrived';

  @override
  String get notifTripCompleted => 'Trip completed';

  @override
  String notifChat(Object name) {
    return 'New message from $name';
  }

  @override
  String get notifTitle => 'Notifications';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatYou => 'You';

  @override
  String get chatDriver => 'Driver';

  @override
  String get chatTypeMessage => 'Type a message...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatNoMessages => 'No messages yet';

  @override
  String get langEn => 'English';

  @override
  String get langCeb => 'Cebuano';

  @override
  String get langTl => 'Tagalog';

  @override
  String get langAppLanguage => 'App Language';

  @override
  String get langChanged => 'Language changed';

  @override
  String get signUpPassengerTitle => 'Sign Up as Passenger';

  @override
  String get signUpPassengerSubtitle =>
      'Sign up to start booking your rides safely and easily.';

  @override
  String get signUpFullName => 'Full Name';

  @override
  String get signUpFullNameHint => 'e.g. Juan Dela Cruz';

  @override
  String get signUpFullNameError =>
      'Please enter your full name (at least 2 characters).';

  @override
  String get signUpMobileNumber => 'Mobile Number';

  @override
  String get signUpMobileHint => '09XX XXX XXXX';

  @override
  String get signUpMobileError =>
      'Please enter a valid 11-digit Philippine mobile number.';

  @override
  String get signUpPassword => 'Password';

  @override
  String get signUpPasswordHint => 'At least 6 characters';

  @override
  String get signUpPasswordError => 'Password must be at least 6 characters.';

  @override
  String get signUpConfirmPassword => 'Confirm Password';

  @override
  String get signUpConfirmPasswordHint => 'Re-enter your password';

  @override
  String get signUpConfirmPasswordError => 'Passwords do not match.';

  @override
  String get signUpTermsText =>
      'I agree to the Terms and Conditions and Privacy Policy';

  @override
  String get signUpTermsRequired =>
      'You must agree to the Terms and Conditions to proceed.';

  @override
  String get signUpButton => 'Sign Up';

  @override
  String get signUpAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get signUpLoginLink => 'Login';

  @override
  String get signUpPreferredLanguage => 'Preferred Language';

  @override
  String get navHome => 'Home';

  @override
  String get navActivity => 'Activity';

  @override
  String get navWallet => 'Wallet';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileClearCache => 'Clear Cache';

  @override
  String get profileClearCacheSubtitle =>
      'Free temporary files, map & weather cache';

  @override
  String profileClearCacheSuccess(Object size) {
    return 'Cache cleared successfully! ($size freed)';
  }

  @override
  String get profileClearCacheConfirm =>
      'Clear temporary cache? Your account and ride records will remain safe.';

  @override
  String get profileLogoutTitle => 'Log Out';

  @override
  String get profileLogoutSubtitle => 'Sign out on this device';

  @override
  String get profileLogoutMessage =>
      'Are you sure you want to log out? Your account and ride records are safely stored on the server.';

  @override
  String get profileLogoutButton => 'Log Out';

  @override
  String get profileDeleteAccountTitle => 'Delete Account';

  @override
  String get profileDeleteAccountSubtitle =>
      'Permanently erase your account and server data';

  @override
  String get profileDeleteAccountWarning =>
      'Are you sure you want to permanently delete your Sakay Ta account? This action cannot be undone and will permanently remove your profile, ride history, and saved data from our servers.';

  @override
  String get profileDeleteAccountConfirmButton => 'Permanently Delete';

  @override
  String get profileDeleteAccountSuccess =>
      'Your account has been deleted successfully.';

  @override
  String get profileSelectLanguage => 'Select Language';

  @override
  String get profileBisayaLanguage => 'Bisaya (Binisaya / Cebuano)';

  @override
  String get profileEnglishLanguage => 'English (US / PH)';

  @override
  String get profileTagalogLanguage => 'Tagalog (Filipino)';

  @override
  String get profileDangerZone => 'Danger Zone';

  @override
  String get homeGreetingMorning => 'Good Morning!';

  @override
  String get homeGreetingAfternoon => 'Good Afternoon!';

  @override
  String get homeGreetingEvening => 'Good Evening!';

  @override
  String get homeWhereTo => 'Where to?';

  @override
  String get homeSearchDestination => 'Search destination...';

  @override
  String get homeQuickDestinations => 'Quick Destinations';

  @override
  String get homeRecentActivity => 'Recent Activity';

  @override
  String get homeNearbyDrivers => 'Nearby Drivers';

  @override
  String get homeNoNearbyDrivers => 'No active drivers in your area right now.';

  @override
  String get homeBookRide => 'Book a Ride';

  @override
  String get homeCurrentLocation => 'Current Location';

  @override
  String get homePopularPlaces => 'Popular Places';

  @override
  String get walletCashIn => 'Cash In / Top Up';

  @override
  String get walletSendMoney => 'Transfer';

  @override
  String get walletAddPaymentMethod => 'Add Payment Method';

  @override
  String get walletLinkedAccounts => 'Linked Accounts';

  @override
  String get walletDefaultPayment => 'Default Payment';

  @override
  String get walletManagePayments => 'Manage Payment Methods';

  @override
  String get walletSavedAccounts => 'Saved Payment Accounts';

  @override
  String get walletHistoryReceipts => 'Payment History & Receipts';

  @override
  String get walletNoRecords => 'No payment records yet.';

  @override
  String get ridesEmptyUpcoming => 'No upcoming rides';

  @override
  String get ridesEmptyUpcomingSubtitle =>
      'Ready to go? Book a ride to see it here.';

  @override
  String get ridesEmptyCompleted => 'No completed trips yet';

  @override
  String get ridesEmptyCompletedSubtitle =>
      'Your ride receipts and completed trip history will appear here.';

  @override
  String get ridesEmptyCancelled => 'No cancelled trips';

  @override
  String get ridesEmptyCancelledSubtitle => 'Cancelled rides will appear here.';

  @override
  String get ridesBookNow => 'Book a Ride Now';
}
