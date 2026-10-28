/// Every user-facing string, in one place, so a later localisation pass is mechanical. Widgets reference these by
/// name, never inline text. The app is Persian only (fa_IR); there is no ARB codegen.
///
/// «‌» in a word is a zero-width non-joiner (U+200C), as Persian writes «ثبت‌نام» or «هم‌بازی».
class AppStrings {
  AppStrings._();

  // App
  /// «رالیتو»: the launcher label (AndroidManifest, Info.plist), the window title and the launch splash's wordmark.
  static const String appName = 'رالیتو';
  static const String appTagline = 'هم‌بازی تنیس، پدل، بدمینتون و اسکواش';

  // Common actions
  static const String retry = 'تلاش مجدد';
  static const String undo = 'بازگردانی';
  static const String signOut = 'خروج از حساب';
  static const String backToHome = 'بازگشت به خانه';

  // Common states
  static const String loading = 'در حال بارگذاری…';
  static const String noResultsTitle = 'نتیجه‌ای پیدا نشد';
  static const String pageNotFound = 'این صفحه پیدا نشد';

  // Errors shown to the player
  static const String genericError = 'خطایی رخ داد. دوباره تلاش کنید';
  static const String offlineActionError = 'برای انجام این کار به اینترنت نیاز دارید';

  /// The session is gone and the refresh token could not renew it: the player has to sign in again.
  static const String sessionExpiredError = 'نشست شما به پایان رسیده است. لطفاً دوباره وارد شوید';
  static const String forbiddenError = 'شما به این بخش دسترسی ندارید';

  // Network errors (ErrorInterceptor), used when the server sent no message of its own
  static const String connectionTimeoutError = 'زمان اتصال به سرور به پایان رسید';
  static const String sendTimeoutError = 'زمان ارسال درخواست به پایان رسید';
  static const String receiveTimeoutError = 'زمان دریافت پاسخ به پایان رسید';
  static const String requestCancelledError = 'درخواست لغو شد';
  static const String connectionError = 'لطفاً اتصال اینترنت خود را بررسی کنید';
  static const String serverUnreachableError = 'خطا در برقراری ارتباط با سرور';
  static const String badRequestError = 'درخواست نامعتبر است';
  static const String unauthorizedError = 'لطفاً وارد حساب کاربری خود شوید';
  static const String notFoundError = 'اطلاعات مورد نظر پیدا نشد';
  static const String conflictError = 'این درخواست با وضعیت فعلی سازگار نیست';
  static const String validationError = 'اطلاعات واردشده نامعتبر است';
  static const String tooManyRequestsError = 'تعداد درخواست‌های شما بیش از حد مجاز است. کمی بعد دوباره تلاش کنید';
  static const String serverError = 'خطای سرور رخ داد';
  static const String serviceUnavailableError = 'سرویس موقتاً در دسترس نیست';

  /// A 401 that ended the account (suspended, banned, inactive) but carried no message of its own.
  static const String accountEndedError = 'دسترسی حساب شما محدود شده است. برای پیگیری با پشتیبانی تماس بگیرید';

  // Sign-in: phone entry
  static const String phoneTitle = 'ورود با شماره موبایل';
  static const String phoneHeading = 'به رالیتو خوش آمدید';
  static const String phoneExplanation =
      'شماره موبایل خود را وارد کنید تا کد ورود برایتان پیامک شود. اگر حساب ندارید، با همین کد ساخته می‌شود.';
  static const String phoneFieldLabel = 'شماره موبایل';
  static const String phoneFieldHint = '۰۹۱۲۳۴۵۶۷۸۹';
  static const String phoneRequired = 'شماره موبایل را وارد کنید';
  static const String phoneInvalid = 'شماره موبایل معتبر نیست؛ مانند ۰۹۱۲۳۴۵۶۷۸۹';
  static const String sendCode = 'دریافت کد';

  /// The send button while the server asks to wait; [time] is «m:ss» in Persian digits.
  static String sendCodeAfter(String time) => 'دریافت کد تا $time دیگر';
  static const String dismiss = 'بستن';

  // Sign-in: code entry
  static const String codeTitle = 'کد تأیید';
  static const String codeHeading = 'کد تأیید را وارد کنید';

  /// [phone] masked (۰۹۱۲•••۴۵۶۷), in Persian digits.
  static String codeSentTo(String phone) => 'کد ۴ رقمی به $phone ارسال شد.';
  static const String codeFieldLabel = 'کد ۴ رقمی ورود';
  static const String editPhone = 'ویرایش شماره';
  static const String verifyCode = 'ورود';
  static const String codeIncomplete = 'کد ۴ رقمی را کامل وارد کنید';
  static const String resendCode = 'ارسال دوباره کد';

  /// [time] is «m:ss» in Persian digits.
  static String resendCodeAfter(String time) => 'ارسال دوباره کد تا $time دیگر';
  static const String codeResent = 'کد جدید پیامک شد';
  static const String accountBlockedTitle = 'ورود ممکن نیست';
  static const String understood = 'متوجه شدم';

  // Onboarding
  static const String onboardingTitle = 'تکمیل پروفایل';

  /// [step] and [total] in Persian digits.
  static String onboardingProgress(String step, String total) => 'مرحله $step از $total';
  static const String next = 'ادامه';
  static const String back = 'قبلی';
  static const String createProfile = 'ثبت پروفایل';
  static const String skip = 'فعلاً نه';
  static const String nameStepTitle = 'دیگران شما را با چه نامی ببینند؟';
  static const String nameStepHint = 'نام نمایشی ۲ تا ۳۰ نویسه است: حرف، عدد و فاصله.';
  static const String displayNameLabel = 'نام نمایشی';
  static const String displayNameRequired = 'نام نمایشی را وارد کنید';
  static const String displayNameInvalid = 'نام نمایشی باید ۲ تا ۳۰ نویسه و فقط حرف، عدد و فاصله باشد';
  static const String genderStepTitle = 'جنسیت';
  static const String genderRequired = 'جنسیت را انتخاب کنید';

  /// The gender step's notice: it is set once.
  static const String genderLockedNotice =
      'جنسیت پس از ثبت پروفایل قابل تغییر نیست. اگر اشتباه انتخاب کنید، فقط پشتیبانی می‌تواند آن را اصلاح کند.';
  static const String birthDateStepTitle = 'تاریخ تولد';
  static const String birthDateHint =
      'برای استفاده از رالیتو باید دست‌کم ۱۸ سال داشته باشید. تاریخ تولد به دیگران نشان داده نمی‌شود؛ فقط بازه سنی.';
  static const String birthDateRequired = 'روز، ماه و سال تولد را انتخاب کنید';
  static const String under18 = 'برای استفاده از رالیتو باید دست‌کم ۱۸ سال داشته باشید';
  static const String dateDay = 'روز';
  static const String dateMonth = 'ماه';
  static const String dateYear = 'سال';
  static const String cityStepTitle = 'کجا بازی می‌کنید؟';
  static const String cityStepHint = 'هم‌بازی‌ها و باشگاه‌ها در شهر شما پیشنهاد می‌شوند.';
  static const String cityRequired = 'شهر را انتخاب کنید';
  static const String chooseCity = 'انتخاب شهر';
  static const String changeCity = 'تغییر شهر';
  static const String sportsStepTitle = 'چه ورزش‌هایی بازی می‌کنید؟';
  static const String sportsStepHint = 'یک یا چند ورزش انتخاب کنید و برای هر کدام سطح و هدفتان را بگویید.';
  static const String sportsRequired = 'دست‌کم یک ورزش انتخاب کنید';
  static const String homeVenuesStepTitle = 'باشگاه‌های همیشگی (اختیاری)';
  static const String homeVenuesStepHint =
      'باشگاه‌هایی که معمولاً در آن‌ها بازی می‌کنید، حداکثر ۵ باشگاه. بعداً هم از پروفایل می‌توانید تغییرشان دهید.';
  static const String chooseHomeVenues = 'انتخاب باشگاه‌ها';
  static const String homeVenuesFailed = 'پروفایل ساخته شد، اما باشگاه‌ها ذخیره نشدند. دوباره تلاش کنید یا رد شوید.';

  // Sport profile
  static const String experienceTitle = 'سابقه بازی';
  static const String formatsTitle = 'قالب بازی';
  static const String goalsTitle = 'هدف از بازی';

  /// [sport] is the sport's Persian name.
  static String sportLevelRequired(String sport) => 'سطح بازی $sport را انتخاب کنید';
  static String sportExperienceRequired(String sport) => 'سابقه بازی $sport را انتخاب کنید';
  static String sportFormatRequired(String sport) => 'دست‌کم یک قالب بازی برای $sport انتخاب کنید';
  static String sportFormatNotAllowed(String sport) => 'این قالب بازی برای $sport مجاز نیست';
  static String sportGoalRequired(String sport) => 'دست‌کم یک هدف برای $sport انتخاب کنید';
  static const String experienceUnderSixMonths = 'کمتر از ۶ ماه';
  static const String experienceSixToTwelveMonths = '۶ تا ۱۲ ماه';
  static const String experienceOneToThreeYears = '۱ تا ۳ سال';
  static const String experienceThreeToFiveYears = '۳ تا ۵ سال';
  static const String experienceOverFiveYears = 'بیش از ۵ سال';
  static const String formatSingles = 'انفرادی';
  static const String formatDoubles = 'دونفره';
  static const String goalRallyPractice = 'تمرین رالی';
  static const String goalFriendlyMatch = 'بازی دوستانه';
  static const String goalCompetitive = 'رقابتی';
  static const String goalFitness = 'تناسب اندام';
  static const String genderMale = 'آقا';
  static const String genderFemale = 'خانم';

  // My profile
  static const String myProfileTitle = 'پروفایل من';
  static const String editProfile = 'ویرایش';
  static const String save = 'ذخیره';
  static const String cancel = 'انصراف';
  static const String remove = 'حذف';
  static const String bioLabel = 'معرفی کوتاه';
  static const String bioHint = 'مثلاً: صبح‌های جمعه بازی می‌کنم و دنبال هم‌بازی هم‌سطح هستم';
  static const String bioTooLong = 'معرفی حداکثر ۳۰۰ نویسه است';
  static const String noBio = 'معرفی‌ای ننوشته‌اید';
  static const String cityLabel = 'شهر';
  static const String genderLabel = 'جنسیت';
  static const String genderCannotChange = 'قابل تغییر نیست';
  static const String ageRangeLabel = 'بازه سنی';

  /// [from] and [to] in Persian digits.
  static String ageRange(String from, String to) => '$from تا $to سال';

  /// [from] in Persian digits.
  static String ageRangeFrom(String from) => '$from سال به بالا';
  static const String sportsTitle = 'ورزش‌ها';
  static const String addSport = 'افزودن ورزش';
  static const String chooseSport = 'انتخاب ورزش';
  static const String editSport = 'ویرایش ورزش';
  static const String allSportsAdded = 'همه ورزش‌ها را اضافه کرده‌اید';

  /// [sport] is the sport's Persian name.
  static String removeSportQuestion(String sport) => '$sport از پروفایل حذف شود؟';
  static const String lastSportProfile = 'دست‌کم یک ورزش باید در پروفایل بماند';
  static const String homeVenuesTitle = 'باشگاه‌های همیشگی';
  static const String noHomeVenues = 'باشگاهی انتخاب نکرده‌اید';
  static const String editHomeVenues = 'ویرایش باشگاه‌ها';
  static const String visibilityTitle = 'چه کسانی مرا ببینند';
  static const String visibilitySameGender = 'فقط هم‌جنس‌ها مرا ببینند';
  static const String visibilityExplanation =
      'با روشن کردن این گزینه، پروفایل و زمان‌های آزادتان فقط به بازیکنان هم‌جنس نشان داده می‌شود و در جستجوی دیگران دیده نمی‌شوید.';
  static const String photoChange = 'تغییر عکس';
  static const String photoAdd = 'افزودن عکس';
  static const String photoRemove = 'حذف عکس';
  static const String photoReadFailed = 'عکس خوانده نشد. عکس دیگری انتخاب کنید';
  static const String blockedPlayersTitle = 'بازیکنان مسدودشده';
  static const String blockedPlayersEmpty = 'کسی را مسدود نکرده‌اید';
  static const String blockedPlayersSubtitle = 'بازیکنان مسدودشده شما را نمی‌بینند و شما هم آن‌ها را نمی‌بینید.';
  static const String unblock = 'رفع مسدودی';

  /// [name] is the player's display name.
  static String unblocked(String name) => '$name از فهرست مسدودها خارج شد';

  /// [date] is a Jalali date for reading.
  static String blockedOn(String date) => 'مسدود از $date';
  static const String saved = 'ذخیره شد';

  // Another player's profile
  static const String playerTitle = 'پروفایل بازیکن';
  static const String playerNotFound = 'بازیکن پیدا نشد';
  static const String block = 'مسدود کردن';

  /// [name] is the player's display name.
  static String blockQuestion(String name) => '$name مسدود شود؟';
  static const String blockExplanation =
      'او دیگر پروفایل و زمان‌های آزاد شما را نمی‌بیند و شما هم او را نمی‌بینید. از «بازیکنان مسدودشده» در پروفایلتان می‌توانید مسدودی را بردارید.';

  /// [name] is the player's display name.
  static String blocked(String name) => '$name مسدود شد';
  static const String lastActiveToday = 'امروز فعال بوده';
  static const String lastActiveThisWeek = 'این هفته فعال بوده';
  static const String lastActiveThisMonth = 'این ماه فعال بوده';
  static const String lastActiveEarlier = 'بیش از یک ماه است فعال نبوده';

  /// [date] is a Jalali month and year for reading.
  static String memberSince(String date) => 'عضو از $date';
  static const String playerAvailabilityTitle = 'زمان‌های آزاد';
  static const String playerAvailabilityEmpty = 'زمان آزادی ثبت نکرده است';

  // Availability
  static const String availabilityTitle = 'زمان‌های آزاد من';
  static const String availabilityEmptyTitle = 'هنوز زمان آزادی ثبت نکرده‌اید';
  static const String availabilityEmptySubtitle = 'بگویید کی و کجا آزادید تا هم‌بازی‌ها پیدایتان کنند.';
  static const String availabilityAdd = 'افزودن زمان آزاد';
  static const String availabilityNewTitle = 'زمان آزاد جدید';
  static const String availabilityEditTitle = 'ویرایش زمان آزاد';
  static const String statusActive = 'فعال';
  static const String statusPaused = 'متوقف';
  static const String statusExpired = 'منقضی';
  static const String kindRecurring = 'هر هفته';
  static const String kindOneOff = 'یک‌باره';
  static const String pause = 'توقف';
  static const String resume = 'فعال‌سازی';
  static const String confirmStillAvailable = 'هنوز آزادم';
  static const String confirmStillAvailableHint = 'زمان‌های هفتگی اگر ۳۰ روز تأیید نشوند خودبه‌خود متوقف می‌شوند.';
  static const String availabilityDeleteQuestion = 'این زمان آزاد حذف شود؟';
  static const String availabilityDeleted = 'زمان آزاد حذف شد';
  static const String availabilityPaused = 'زمان آزاد متوقف شد';
  static const String availabilityResumed = 'زمان آزاد دوباره فعال شد';
  static const String availabilityConfirmed = 'ثبت شد که هنوز آزادید';
  static const String availabilitySaved = 'زمان آزاد ذخیره شد';

  /// [start] and [end] are «HH:mm» in Persian digits.
  static String timeRange(String start, String end) => '$start تا $end';

  /// [date] is a Jalali date for reading.
  static String validUntil(String date) => 'تا $date';
  static const String sportLabel = 'ورزش';
  static const String sportRequired = 'ورزش را انتخاب کنید';
  static const String noSportProfiles = 'اول از پروفایل یک ورزش اضافه کنید';
  static const String kindLabel = 'تکرار';
  static const String weekdaysLabel = 'روزهای هفته';
  static const String weekdaysRequired = 'دست‌کم یک روز هفته را انتخاب کنید';
  static const String dateLabel = 'تاریخ';
  static const String dateRequired = 'تاریخ را انتخاب کنید';
  static const String startTimeLabel = 'از ساعت';
  static const String endTimeLabel = 'تا ساعت';
  static const String timeHint = 'به وقت تهران؛ دست‌کم یک ساعت، با گام‌های نیم‌ساعته.';
  static const String venuesLabel = 'باشگاه‌ها';

  /// [max] in Persian digits.
  static String venuesHint(String max) => 'حداکثر $max باشگاه در شهر شما که این ورزش را دارند';
  static const String venuesRequired = 'دست‌کم یک باشگاه انتخاب کنید';

  /// [max] in Persian digits.
  static String venuesTooMany(String max) => 'حداکثر $max باشگاه می‌توانید انتخاب کنید';
  static const String noteLabel = 'یادداشت (اختیاری)';

  /// [max] in Persian digits.
  static String noteTooLong(String max) => 'یادداشت حداکثر $max نویسه است';
  static const String validUntilLabel = 'معتبر تا (اختیاری)';
  static const String validUntilClear = 'بدون تاریخ پایان';
  static const String validUntilInPast = 'تاریخ پایان نمی‌تواند گذشته باشد';
  static const String formatsRequired = 'دست‌کم یک قالب بازی انتخاب کنید';
  static const String formatNotAllowed = 'این قالب بازی برای این ورزش مجاز نیست';

  // Availability: the server's rules, in its own words, checked on the device first
  static const String windowTooShort = 'هر بازه دست‌کم ۶۰ دقیقه است';
  static const String windowCrossesMidnight = 'بازه نباید از نیمه‌شب بگذرد؛ آن را به دو بازه تقسیم کنید';
  static const String invalidTimeStep = 'ساعت‌ها باید مضرب ۳۰ دقیقه باشند';
  static const String invalidTime = 'ساعت واردشده معتبر نیست';
  static const String dateTooFar = 'تاریخ حداکثر ۶۰ روز بعد می‌تواند باشد';
  static const String windowInPast = 'این زمان گذشته است';

  // Home
  static const String homeTitle = 'خانه';
  static const String homePlaceholder = 'به‌زودی هم‌بازی پیدا می‌کنید و بازی می‌سازید.';

  // Partner search
  static const String searchTitle = 'جستجوی هم‌بازی';
  static const String searchFilters = 'فیلترها';
  static const String searchApply = 'جستجو';
  static const String searchPlayersTitle = 'بازیکنان';
  static const String searchPostsTitle = 'آگهی‌های بازی';
  static const String resultTypeLabel = 'نمایش';
  static const String resultTypeBoth = 'همه';
  static const String resultTypePlayers = 'بازیکنان';
  static const String resultTypePosts = 'آگهی‌ها';
  static const String searchEmptyTitle = 'با این فیلترها نتیجه‌ای پیدا نشد';
  static const String searchEmptySubtitle = 'بازه زمانی، سطح یا باشگاه‌ها را گسترده‌تر کنید.';
  static const String loadMore = 'نتایج بیشتر';
  static const String whenLabel = 'چه روزی';
  static const String whenWeekdays = 'روزهای هفته';
  static const String whenDate = 'تاریخ مشخص';
  static const String anyDay = 'همه روزها';
  static const String anyDayHint = 'اگر روزی انتخاب نکنید، همه روزها جستجو می‌شوند.';
  static const String wholeDay = 'تمام روز';
  static const String allVenues = 'همه باشگاه‌های شهر';
  static const String allVenuesHint =
      'اگر باشگاهی انتخاب نکنید، همه باشگاه‌های شهر که این ورزش را دارند جستجو می‌شوند.';
  static const String levelsLabel = 'سطح هم‌بازی';
  static const String levelFrom = 'از سطح';
  static const String levelTo = 'تا سطح';
  static const String partnerGenderLabel = 'جنسیت هم‌بازی';
  static const String genderLockedHint = 'چون فقط هم‌جنس‌ها شما را می‌بینند، فقط هم‌جنس‌ها جستجو و دعوت می‌شوند.';
  static const String formatAny = 'همه قالب‌ها';

  /// [start] and [end] are «HH:mm» in Persian digits.
  static String overlap(String start, String end) => 'هم‌پوشانی $start تا $end';
  static const String searchDateOutOfRange = 'تاریخ جستجو باید از امروز تا ۳۰ روز آینده باشد';
  static const String invalidTimeRange = 'ساعت پایان باید بعد از ساعت شروع باشد';
  static const String invalidDate = 'تاریخ معتبر نیست';
  static const String unknownSport = 'ورزش انتخاب‌شده وجود ندارد';
  static const String profileRequired = 'ابتدا پروفایل خود را کامل کنید';
  static const String viewProfile = 'مشاهده پروفایل';
  static const String inviteToGame = 'دعوت به بازی';

  // Saved searches
  static const String saveSearch = 'ذخیره جستجو';
  static const String saveSearchTitle = 'ذخیره این جستجو';
  static const String savedSearchNameLabel = 'نام جستجو';
  static const String savedSearchAlerts = 'وقتی مورد تازه‌ای پیدا شد خبرم کن';
  static const String searchSaved = 'جستجو ذخیره شد';
  static const String savedSearchesTitle = 'جستجوهای ذخیره‌شده';
  static const String savedSearchesEmptyTitle = 'جستجویی ذخیره نکرده‌اید';
  static const String savedSearchesEmptySubtitle =
      'از صفحه جستجو فیلترهایتان را ذخیره کنید تا از هم‌بازی‌ها و آگهی‌های تازه باخبر شوید.';
  static const String savedSearchDeleted = 'جستجو حذف شد';
  static const String alertsOn = 'هشدار این جستجو روشن شد';
  static const String alertsOff = 'هشدار این جستجو خاموش شد';
  static const String alertsLabel = 'هشدار';
  static const String runSearch = 'اجرای جستجو';
  static const String tooManySavedSearches = 'حداکثر ۵ جستجو را می‌توانید ذخیره کنید';
  static const String invalidSavedSearchName = 'نام جستجو ۱ تا ۴۰ نویسه است';

  /// [count] and [max] in Persian digits.
  static String savedSearchCount(String count, String max) => '$count از $max جستجو';

  /// [name] is the saved search's name.
  static String savedSearchDeleteQuestion(String name) => 'جستجوی «$name» حذف شود؟';

  /// [date] is a Jalali date for reading.
  static String savedSearchExpires(String date) => 'معتبر تا $date';

  /// [count] in Persian digits.
  static String savedSearchPending(String count) => '$count مورد تازه در انتظار هشدار';

  // Matches: labels
  static const String myMatchesTitle = 'بازی‌های من';
  static const String matchStatusOpen = 'باز';
  static const String matchStatusPending = 'در انتظار پاسخ دعوت';
  static const String matchStatusConfirmed = 'قطعی';
  static const String matchStatusCompleted = 'برگزار شد';
  static const String matchStatusDisputed = 'مورد اختلاف';
  static const String matchStatusUnconfirmed = 'تأییدنشده';
  static const String matchStatusCancelled = 'لغو شد';
  static const String matchStatusExpired = 'منقضی شد';
  static const String participantHost = 'میزبان';
  static const String participantInvited = 'دعوت‌شده';
  static const String participantRequested = 'درخواست داده';
  static const String participantAccepted = 'پذیرفته‌شده';
  static const String participantDeclined = 'ردشده';
  static const String participantWithdrawn = 'انصراف داده';
  static const String participantLeft = 'خارج شده';
  static const String participantRemoved = 'حذف‌شده';
  static const String participantExpired = 'منقضی';
  static const String myStateHost = 'شما میزبان این بازی هستید';
  static const String myStateInvited = 'شما به این بازی دعوت شده‌اید';
  static const String myStateRequested = 'درخواست شما در انتظار پاسخ میزبان است';
  static const String myStateAccepted = 'شما در این بازی هستید';
  static const String myStateDeclined = 'شما در این بازی نیستید';
  static const String myStateWithdrawn = 'درخواستتان را پس گرفتید';
  static const String myStateLeft = 'از این بازی خارج شدید';
  static const String myStateRemoved = 'میزبان شما را از این بازی حذف کرد';
  static const String myStateExpired = 'این درخواست یا دعوت منقضی شد';
  static const String partnerGenderAny = 'همه';
  static const String partnerGenderMale = 'فقط آقایان';
  static const String partnerGenderFemale = 'فقط خانم‌ها';
  static const String matchPublic = 'آگهی عمومی';
  static const String matchPrivate = 'دعوت خصوصی';
  static const String tierBeginner = 'مبتدی';
  static const String tierLowerIntermediate = 'متوسط رو به پایین';
  static const String tierIntermediate = 'متوسط';
  static const String tierAdvanced = 'پیشرفته';
  static const String tierProfessional = 'حرفه‌ای';

  /// [from] and [to] are level names.
  static String levelRange(String from, String to) => '$from تا $to';

  /// [open] and [capacity] in Persian digits.
  static String openSpots(String open, String capacity) => '$open جای خالی از $capacity';

  /// [minutes] in Persian digits.
  static String durationMinutes(String minutes) => '$minutes دقیقه';

  // Matches: the server's refusals
  static const String matchNotAvailable = 'این بازی در دسترس نیست';
  static const String shareLinkInvalid = 'این پیوند دیگر معتبر نیست';
  static const String scheduleConflict = 'در این زمان بازی دیگری دارید';
  static const String noOpenSpot = 'جای خالی در این بازی نمانده است';
  static const String matchClosed = 'این بازی دیگر بازیکن نمی‌پذیرد';
  static const String matchStarted = 'این بازی شروع شده است';
  static const String matchFinished = 'این بازی تمام شده است';
  static const String alreadyInMatch = 'قبلاً در این بازی هستید یا درخواست داده‌اید';
  static const String notAPost = 'این بازی دعوت خصوصی است';
  static const String notTheHost = 'فقط میزبان این کار را می‌تواند انجام دهد';
  static const String notAParticipant = 'این بازیکن در بازی نیست';
  static const String notEnoughPlayers = 'برای قطعی کردن بازی دست‌کم دو بازیکن لازم است';
  static const String invalidParticipantState = 'این کار در وضعیت فعلی شما در بازی ممکن نیست';
  static const String tooManyOpenPosts = 'حداکثر ۵ آگهی باز می‌توانید داشته باشید';
  static const String tooManyPendingRequests = 'حداکثر ۱۰ درخواست در انتظار می‌توانید داشته باشید';
  static const String tooManyInvitees = 'ظرفیت این بازی برای این تعداد دعوت کافی نیست';
  static const String inviteeDoesNotPlay = 'این بازیکن این ورزش را بازی نمی‌کند';
  static const String noSportProfileForMatch = 'ابتدا این ورزش را به پروفایل خود اضافه کنید';
  static const String unknownVenue = 'باشگاه انتخاب‌شده در دسترس نیست';
  static const String venueDoesNotOfferSport = 'باشگاه انتخاب‌شده این ورزش را ندارد';
  static const String invalidDuration = 'مدت بازی باید ۶۰ تا ۲۴۰ دقیقه و مضرب ۳۰ دقیقه باشد';
  static const String startTooSoon = 'زمان شروع باید دست‌کم ۳۰ دقیقه بعد باشد';
  static const String startTooFar = 'زمان شروع حداکثر ۳۰ روز بعد است';
  static const String invalidPlayersBrought = 'تعداد همراهان با ظرفیت بازی جور نیست';
  static const String messageTooLong = 'پیام حداکثر ۲۰۰ نویسه است';
  static const String costNoteTooLong = 'یادداشت هزینه حداکثر ۲۰۰ نویسه است';
  static const String descriptionTooLong = 'توضیحات حداکثر ۵۰۰ نویسه است';

  // Matches: my matches
  static const String upcomingMatches = 'پیش رو';
  static const String pastMatches = 'گذشته';
  static const String upcomingEmptyTitle = 'بازی پیش رویی ندارید';
  static const String upcomingEmptySubtitle = 'آگهی بازی بگذارید یا از جستجو هم‌بازی پیدا کنید.';
  static const String pastEmptyTitle = 'هنوز بازی گذشته‌ای ندارید';
  static const String newPost = 'آگهی بازی';
  static const String openShareLink = 'باز کردن پیوند بازی';
  static const String shareLinkLabel = 'پیوند یا کد بازی';
  static const String shareLinkHint = 'پیوندی را که برایتان فرستاده‌اند اینجا بچسبانید';
  static const String shareLinkNotRecognised = 'این پیوند بازی رالیتو نیست';
  static const String open = 'باز کردن';

  // Matches: creating a post or an invitation
  static const String newPostTitle = 'آگهی بازی جدید';
  static const String newInvitationTitle = 'دعوت به بازی';

  /// [name] is the invited player's display name.
  static String inviteTo(String name) => 'دعوت از $name';
  static const String venueLabel = 'باشگاه';
  static const String chooseVenue = 'انتخاب باشگاه';
  static const String venueRequired = 'باشگاه را انتخاب کنید';
  static const String matchStartLabel = 'ساعت شروع';
  static const String matchTimeHint = 'به وقت تهران؛ دست‌کم ۳۰ دقیقه و حداکثر ۳۰ روز بعد.';
  static const String durationLabel = 'مدت بازی';
  static const String playersBroughtLabel = 'همراهان شما';

  /// [max] in Persian digits.
  static String playersBroughtHint(String max) => 'چند نفر را خودتان می‌آورید؟ حداکثر $max نفر';

  /// [count] in Persian digits.
  static String openSpotsPreview(String count) => 'جای خالی برای دیگران: $count';
  static const String courtBookedLabel = 'زمین رزرو شده است';
  static const String courtNotBooked = 'زمین هنوز رزرو نشده است';
  static const String costNoteLabel = 'تقسیم هزینه (اختیاری)';
  static const String costNoteHint = 'مثلاً: هزینه زمین بین بازیکنان تقسیم می‌شود';
  static const String descriptionLabel = 'توضیحات (اختیاری)';
  static const String inviteMessageLabel = 'پیام (اختیاری)';
  static const String publishPost = 'ثبت آگهی';
  static const String sendInvitation = 'ارسال دعوت';
  static const String postPublished = 'آگهی بازی ثبت شد';
  static const String invitationSent = 'دعوت فرستاده شد';
  static const String inviteIntoPostTitle = 'دعوت به یکی از بازی‌های بازتان';
  static const String newGameTitle = 'یا یک بازی تازه بسازید';

  // Matches: details and actions
  static const String matchTitle = 'جزئیات بازی';
  static const String hostLabel = 'میزبان';
  static const String playersLabel = 'بازیکنان';
  static const String requestsLabel = 'درخواست‌های پیوستن';
  static const String invitedLabel = 'دعوت‌شده‌ها';
  static const String outOfRange = 'خارج از بازه سطح شما';
  static const String join = 'درخواست پیوستن';
  static const String joinTitle = 'درخواست پیوستن به بازی';
  static const String joinMessageLabel = 'پیام به میزبان (اختیاری)';
  static const String send = 'ارسال';
  static const String joinRequested = 'درخواست شما فرستاده شد';
  static const String withdraw = 'پس گرفتن درخواست';
  static const String requestWithdrawn = 'درخواست پس گرفته شد';
  static const String accept = 'پذیرفتن';
  static const String decline = 'رد کردن';
  static const String requestAccepted = 'درخواست پذیرفته شد';
  static const String requestDeclined = 'درخواست رد شد';
  static const String acceptInvitation = 'پذیرفتن دعوت';
  static const String declineInvitation = 'رد دعوت';
  static const String invitationAccepted = 'دعوت را پذیرفتید';
  static const String invitationDeclined = 'دعوت را رد کردید';
  static const String confirmEarly = 'قطعی کردن بازی';
  static const String confirmEarlyQuestion = 'بازی با همین بازیکنان قطعی شود؟ دیگر درخواست تازه‌ای پذیرفته نمی‌شود.';
  static const String matchConfirmed = 'بازی قطعی شد';
  static const String leave = 'خروج از بازی';
  static const String leaveQuestion = 'از این بازی خارج می‌شوید؟';
  static const String matchLeft = 'از بازی خارج شدید';
  static const String cancelMatch = 'لغو بازی';
  static const String cancelMatchQuestion = 'این بازی لغو شود؟ همه بازیکنان باخبر می‌شوند.';
  static const String cancelReasonLabel = 'دلیل (اختیاری)';
  static const String matchCancelled = 'بازی لغو شد';
  static const String keep = 'نه';

  /// [name] is the player's display name.
  static String removeParticipantQuestion(String name) => '$name از بازی حذف شود؟';
  static const String participantRemovedDone = 'بازیکن حذف شد';
  static const String lateCancellationWarning =
      'کمتر از ۱۲ ساعت به شروع این بازی قطعی مانده است؛ این کار به‌عنوان لغو دیرهنگام در سابقه شما ثبت می‌شود.';
  static const String shareTitle = 'پیوند اشتراک';
  static const String shareHint = 'این پیوند را در گروه‌ها بفرستید تا دیگران آگهی شما را ببینند.';
  static const String copyLink = 'کپی پیوند';
  static const String linkCopied = 'پیوند کپی شد';
  static const String regenerateLink = 'پیوند تازه';
  static const String regenerateLinkQuestion = 'پیوند تازه ساخته شود؟ پیوند قبلی دیگر کار نمی‌کند.';
  static const String linkRegenerated = 'پیوند تازه ساخته شد';
  static const String invitePlayers = 'دعوت از بازیکن';
  static const String descriptionTitle = 'توضیحات';

  /// [reason] is the host's own words.
  static String cancelReason(String reason) => 'دلیل لغو: $reason';
  static const String matchGroupChat = 'گفتگوی گروهی بازی';

  /// [name] is the player's display name.

  // Matches: sharing a public game's link
  static const String shareMatch = 'اشتراک‌گذاری';
  static const String shareHintPublic = 'این بازی را برای دوستان و گروه‌هایتان بفرستید.';
  static const String shareSubject = 'هم‌بازی در رالیتو';
  static const String shareFailed = 'اشتراک‌گذاری ممکن نشد';

  /// [title] «تنیس • انفرادی», [venue] the club, [when] the day and time, [url] the share link.
  static String shareText(String title, String venue, String when, String url) =>
      'هم‌بازی می‌خواهیم: $title\n$venue ‏•‏ $when\n$url';

  // Matches: attendance, once the game ended
  static const String attendanceTitle = 'بازی برگزار شد؟';
  static const String attendancePlayed = 'بازی انجام شد';
  static const String attendanceDidNotHappen = 'بازی انجام نشد';
  static const String noShowTitle = 'کسی نیامد؟ (اختیاری)';
  static const String noShowHint = 'بازیکنانی را که سر بازی نیامدند علامت بزنید.';
  static const String submitAttendance = 'ثبت پاسخ';
  static const String attendanceSaved = 'پاسخ شما ثبت شد';
  static const String attendanceWaiting = 'منتظر پاسخ بقیهٔ بازیکنان هستیم.';
  static const String attendanceWindowOver = 'مهلت پاسخ به این پرسش تمام شده است.';

  /// [when] is the deadline, in Persian.
  static String attendanceDeadline(String when) => 'مهلت پاسخ: $when';

  /// [answer] is «بازی انجام شد» or «بازی انجام نشد».
  static String myAttendanceAnswer(String answer) => 'پاسخ شما: $answer';

  /// [outcome] is what this player's attendance counted as.
  static String myAttendanceOutcome(String outcome) => 'حضور شما: $outcome';
  static const String outcomePlayed = 'بازی کرد';
  static const String outcomeNoShow = 'نیامد';
  static const String outcomeContested = 'مورد اختلاف';
  static const String resolutionCompleted = 'برگزاری این بازی ثبت شد.';
  static const String resolutionDisputed = 'پاسخ بازیکنان با هم جور نبود؛ این بازی در امتیاز و اعتبار کسی اثری ندارد.';
  static const String resolutionUnconfirmed = 'برگزاری این بازی تأیید نشد؛ در امتیاز و اعتبار کسی اثری ندارد.';
  static const String attendanceNotOpen = 'پرسش حضور بعد از پایان بازی باز می‌شود';
  static const String attendanceClosed = 'مهلت اعلام حضور تمام شده است';
  static const String alreadyAnswered = 'قبلاً حضور را اعلام کرده‌اید';
  static const String invalidNoShow = 'غایب را فقط از میان بازیکنان دیگرِ بازیِ انجام‌شده می‌توانید انتخاب کنید';

  // Matches: rating the other players
  static const String rateTitle = 'امتیاز به هم‌بازی‌ها';
  static const String rateHint = 'تا ۷ روز بعد از ثبت نتیجهٔ بازی می‌توانید امتیاز بدهید.';

  /// [name] is the player's display name.
  static String ratePlayer(String name) => 'امتیاز به $name';

  // Ratings: the form
  static const String ratingFormTitle = 'امتیازدهی';
  static const String ratingDefaultName = 'هم‌بازی';
  static const String ratingBlindNotice =
      'امتیاز شما پنهان می‌ماند تا هم‌بازی‌تان هم به شما امتیاز بدهد یا ۷ روز بگذرد. امتیاز ثبت‌شده قابل ویرایش نیست.';
  static const String starsLabel = 'چند ستاره؟';

  /// [count] in Persian digits.
  static String starsTooltip(String count) => '$count ستاره';
  static const String tagsLabel = 'برچسب‌ها (حداکثر ۳)';
  static const String tagOnTime = 'وقت‌شناس';
  static const String tagFriendly = 'خوش‌برخورد';
  static const String tagFairCalls = 'داوری منصفانه';
  static const String tagGoodRally = 'رالی خوب';
  static const String tagSportsmanship = 'روحیه ورزشی';
  static const String tagWellOrganised = 'هماهنگی خوب';
  static const String levelAccuracyLabel = 'سطح بازی او نسبت به سطح اعلام‌شده‌اش چطور بود؟';
  static const String levelLower = 'کمتر از سطح اعلام‌شده';
  static const String levelAboutRight = 'درست';
  static const String levelHigher = 'بیشتر';
  static const String privateNoteLabel = 'یادداشت خصوصی (اختیاری)';
  static const String privateNoteHint = 'فقط مدیران رالیتو این یادداشت را می‌بینند؛ به بازیکن نشان داده نمی‌شود.';
  static const String submitRating = 'ثبت امتیاز';
  static const String ratingSubmitted = 'امتیاز شما ثبت شد';
  static const String ratingNotAllowed = 'امتیازدادن به این بازیکن در این بازی ممکن نیست';
  static const String ratingWindowClosed = 'مهلت امتیازدادن به این بازی تمام شده است';
  static const String alreadyRated = 'قبلاً به این بازیکن برای این بازی امتیاز داده‌اید';
  static const String cannotRateSelf = 'نمی‌توانید به خودتان امتیاز بدهید';
  static const String invalidStars = 'امتیاز باید بین ۱ تا ۵ ستاره باشد';
  static const String tooManyTags = 'حداکثر ۳ برچسب می‌توانید انتخاب کنید';
  static const String levelAccuracyRequired = 'بگویید سطح اعلام‌شدهٔ این بازیکن چقدر درست بود';
  static const String ratingNoteTooLong = 'یادداشت حداکثر ۵۰۰ نویسه است';

  // Ratings: reputation on a profile
  static const String reputationNewPlayer = 'بازیکن جدید';

  /// [average] «۴٫۳» and [count] in Persian digits.
  static String starAverage(String average, String count) => '$average ستاره از $count امتیاز';

  /// The short count after a search card's star average: «(۱۸ امتیاز)». [count] in Persian digits.
  static String ratingCountShort(String count) => '($count امتیاز)';

  /// Read out for a search card's stars: «امتیاز ۴٫۸ از ۱۸ امتیاز».
  static String ratingSemantics(String average, String count) => 'امتیاز $average از $count امتیاز';

  /// [level] is «درست», «بالاتر» or «پایین‌تر».
  // Whole sentences: «سطح اعلام‌شده بالاتر است» could be read as "the declared level is too high".
  static const String levelStatementAboutRight = 'بیشتر هم‌بازی‌ها می‌گویند سطح اعلام‌شده درست است';
  static const String levelStatementHigher = 'بیشتر هم‌بازی‌ها می‌گویند بهتر از سطح اعلام‌شده بازی می‌کند';
  static const String levelStatementLower = 'بیشتر هم‌بازی‌ها می‌گویند پایین‌تر از سطح اعلام‌شده بازی می‌کند';
  static const String reliabilityNew = 'تازه‌وارد';

  /// [tier] is «کم», «خوب» or «عالی».
  static String reliability(String tier) => 'خوش‌قولی: $tier';
  static const String reliabilityLow = 'کم';
  static const String reliabilityGood = 'خوب';
  static const String reliabilityHigh = 'عالی';

  // Redesign: matches and ratings
  static const String you = 'شما';

  /// Joins names in a caption: «سارا، رضا».
  static const String nameSeparator = '، ';

  /// [count] in Persian digits.
  static String upcomingCount(String count) => 'پیش‌رو ($count)';
  static const String matchFilterAll = 'همه';
  static const String matchFilterConfirmed = 'قطعی';
  static const String matchFilterWaiting = 'در انتظار';
  static const String matchFilterPlayed = 'برگزارشده';
  static const String matchFilterCancelled = 'لغوشده';
  static const String matchFilterEmpty = 'بازی‌ای با این وضعیت ندارید';
  static const String matchFilterShowAll = 'نمایش همه';

  /// [sport] is the sport's name, [venue] the club's.
  static String matchCardTitle(String sport, String venue) => '$sport در $venue';

  /// [names] are the other players' names.
  static String youAnd(String names) => 'شما و $names';

  /// [count] in Persian digits.
  static String youAndOthers(String count) => 'شما و $count نفر دیگر';
  static const String justYou = 'فعلاً فقط شما';

  /// [name] is the host's display name.
  static String hostedBy(String name) => 'میزبان: $name';
  static const String pasteLinkTitle = 'لینک بازی دارید؟';
  static const String pasteLinkSubtitle = 'لینک اشتراک‌گذاری‌شده را باز کنید.';
  static const String pasteLinkAction = 'چسباندن';
  static const String matchMoreActions = 'گزینه‌های بیشتر';

  /// «بازی عصر شنبه»: [part] is the part of the day, [weekday] the day's name.
  static String matchCoverTitle(String part, String weekday) => 'بازی $part $weekday'.trim();
  static const String dayPartMorning = 'صبح';
  static const String dayPartNoon = 'ظهر';
  static const String dayPartAfternoon = 'عصر';
  static const String dayPartNight = 'شب';
  static const String statDuration = 'مدت';
  static const String statLevel = 'سطح';
  static const String statCourt = 'زمین';
  static const String courtBookedShort = 'رزرو شده';
  static const String courtNotBookedShort = 'رزرو نشده';
  static const String levelUnknown = 'نامشخص';

  /// [count] and [capacity] in Persian digits.
  static String playersCount(String count, String capacity) => 'بازیکن‌ها ($count از $capacity)';
  static const String aboutMatchTitle = 'درباره بازی';
  static const String costLabel = 'تقسیم هزینه';
  static const String matchTypeLabel = 'نوع بازی';
  static const String confirmedBannerTitle = 'بازی قطعی شد';
  static const String confirmedBannerBody = 'جای همه بازیکنان قطعی است. هماهنگی را در گفتگوی بازی انجام دهید.';
  static const String lateCancellationPolicy =
      'لغو بازی قطعی کمتر از ۱۲ ساعت مانده به شروع، روی خوش‌قولی شما اثر می‌گذارد.';
  static const String acceptShort = 'پذیرش';
  static const String declineShort = 'رد';
  static const String chooseGameLabel = 'انتخاب بازی';
  static const String createNewGame = 'ساخت بازی جدید';
  static const String newGameDetails = 'جزئیات بازی جدید';

  /// The bold part of the open-spots box; [count] in Persian digits.
  static String openSpotsCount(String count) => '$count جای خالی';

  /// [count] in Persian digits.
  static String openSpotsPost(String count) => 'این آگهی $count جای خالی خواهد داشت.';

  /// [count] in Persian digits.
  static String openSpotsGame(String count) => 'این بازی $count جای خالی خواهد داشت.';
  static const String courtBookedHint = 'فقط وضعیت رزرو را اعلام می‌کنید.';

  /// [name] is the invited player's display name.
  static String inviteMessageHint(String name) => 'سلام $name، برای بازی وقت داری؟';

  /// A text counter; [count] and [max] in Persian digits.
  static String countOf(String count, String max) => '$count از $max';
  static const String inviteContactNote = 'شماره تماس شما نمایش داده نمی‌شود. هماهنگی را در رالیتو انجام دهید.';
  static const String levelsPickerDone = 'تأیید';
  static const String ratingBlindTitle = 'امتیاز دوطرفه و پنهان';
  static const String privateNoteAdminsOnly = 'فقط مدیران می‌بینند';
  static const String clearVenue = 'برداشتن باشگاه';

  // Reports
  static const String reportPlayer = 'گزارش این بازیکن';
  static const String reportPhoto = 'گزارش عکس پروفایل';
  static const String reportMessage = 'گزارش پیام';
  static const String reportPost = 'گزارش این آگهی';
  static const String moreActions = 'کارهای بیشتر';
  static const String reportPlayerTitle = 'گزارش بازیکن';
  static const String reportMessageTitle = 'گزارش پیام';
  static const String reportPostTitle = 'گزارش آگهی بازی';
  static const String reportPhotoTitle = 'گزارش عکس پروفایل';
  static const String reportReasonLabel = 'دلیل گزارش';
  static const String reasonHarassment = 'آزار و مزاحمت';
  static const String reasonInappropriateContent = 'محتوای نامناسب';
  static const String reasonFakeProfile = 'پروفایل جعلی';
  static const String reasonSpam = 'هرزنامه یا تبلیغات';
  static const String reasonUnsafeBehaviour = 'رفتار ناامن یا غیبت‌های مکرر';
  static const String reasonUnderage = 'کاربر زیر سن قانونی';
  static const String reasonOther = 'دیگر';
  static const String reportDetailsLabel = 'توضیحات (اختیاری)';
  static const String reportBlockLabel = 'این بازیکن را هم مسدود کن';

  /// [name] is the player's display name.
  static String reportBlockNamed(String name) => '$name را هم مسدود کن';
  static const String reportBlockHint = 'دیگر شما را در جستجو نمی‌بیند و نمی‌تواند به شما پیام بدهد.';
  static const String reportReviewHint = 'مدیران رالیتو گزارش را بررسی می‌کنند. وضعیتش را در «گزارش‌های من» می‌بینید.';
  static const String submitReport = 'ارسال گزارش';
  static const String reportSent = 'گزارش شما فرستاده شد';
  static const String reportSentAndBlocked = 'گزارش شما فرستاده شد و این بازیکن مسدود شد';
  static const String reportReasonRequired = 'دلیل گزارش را انتخاب کنید';
  static const String alreadyReported = 'قبلاً این مورد را گزارش داده‌اید';
  static const String reportMessageNotFound = 'این پیام پیدا نشد';
  static const String reportPhotoNotFound = 'عکسی برای گزارش وجود ندارد';
  static const String reportPostNotFound = 'این آگهی پیدا نشد';
  static const String cannotReportSelf = 'نمی‌توانید از خودتان گزارش بدهید';
  static const String reportDetailsTooLong = 'توضیحات حداکثر ۱۰۰۰ نویسه است';
  static const String reportTooManyRequests = 'گزارش‌های زیادی فرستاده‌اید. کمی بعد دوباره تلاش کنید';

  // Reports: my reports
  static const String myReportsTitle = 'گزارش‌های من';
  static const String myReportsEmpty = 'گزارشی نفرستاده‌اید';
  static const String myReportsHint = 'اینجا فقط وضعیت گزارش‌هایتان را می‌بینید، نه اقدامی که انجام شد.';
  static const String reportStatusOpen = 'در حال بررسی';
  static const String reportStatusResolved = 'بررسی شد';
  static const String reportTargetPlayer = 'بازیکن';
  static const String reportTargetMessage = 'پیام';
  static const String reportTargetPost = 'آگهی بازی';
  static const String reportTargetPhoto = 'عکس پروفایل';

  /// [date] is the Jalali date the report was sent.
  static String reportedOn(String date) => 'فرستاده‌شده در $date';

  // Chat: inbox
  static const String chatTitle = 'پیام‌ها';
  static const String sendMessage = 'پیام دادن';
  static const String conversationsTab = 'گفتگوها';
  static const String requestsTab = 'درخواست‌ها';
  static const String conversationsEmptyTitle = 'هنوز گفتگویی ندارید';
  static const String conversationsEmptySubtitle = 'از صفحهٔ یک بازیکن یا نتیجهٔ جستجو به او پیام بدهید.';
  static const String requestsEmptyTitle = 'درخواست پیامی ندارید';
  static const String requestsEmptySubtitle = 'پیام اول کسانی که هنوز با آن‌ها بازی نکرده‌اید اینجا می‌آید.';
  static const String noMessagesYet = 'هنوز پیامی نیست';
  static const String mutedLabel = 'بی‌صدا';

  // Chat: a conversation
  static const String conversationTitle = 'گفتگو';
  static const String messageHint = 'پیام…';
  static const String deletedMessage = 'پیام حذف شد';
  static const String messageRead = 'خوانده شد';
  static const String messagePending = 'در حال ارسال…';
  static const String messageFailed = 'ارسال نشد';
  static const String retrySend = 'ارسال دوباره';
  static const String discardMessage = 'کنار گذاشتن';
  static const String deleteMessage = 'حذف پیام';
  static const String deleteMessageQuestion = 'این پیام برای همه حذف شود؟';
  static const String messageDeleted = 'پیام حذف شد';
  static const String cannotReplyFooter = 'دیگر نمی‌توانید در این گفتگو پیام بفرستید';
  static const String requestSentFooter = 'پیام شما فرستاده شد. تا پذیرفتن درخواست صبر کنید.';
  static const String loadOlderMessages = 'پیام‌های قبلی';
  static const String mute = 'بی‌صدا کردن';
  static const String unmute = 'صدادار کردن';
  static const String conversationMuted = 'گفتگو بی‌صدا شد';
  static const String conversationUnmuted = 'گفتگو صدادار شد';
  static const String matchChatMissing = 'این بازی هنوز گفتگوی گروهی ندارد';
  static const String matchChatMissingHint = 'گفتگوی گروهی وقتی ساخته می‌شود که دست‌کم دو بازیکن پذیرفته شده باشند.';

  // Chat: safety notice in a new conversation or a request
  static const String safetyTitle = 'برای امنیت شما';
  static const String safetyMeetAtClubs = 'فقط در باشگاه‌ها قرار بگذارید.';
  static const String safetyNoPersonalDetails = 'اطلاعات شخصی مثل شماره تلفن و نشانی را به اشتراک نگذارید.';
  static const String safetyBlockReport = 'هر وقت لازم شد، از مسدود کردن و گزارش استفاده کنید.';

  // Chat: a message request, for its recipient
  /// [name] is the sender's display name.
  static String requestFrom(String name) => '$name می‌خواهد با شما گفتگو کند';
  static const String requestHint = 'تا وقتی درخواست را نپذیرید، فرستنده نمی‌تواند پیام دیگری بفرستد.';
  static const String acceptRequest = 'پذیرفتن';
  static const String ignoreRequest = 'نادیده گرفتن';
  static const String blockSender = 'مسدود کردن';
  static const String requestAcceptedDone = 'درخواست پذیرفته شد';
  static const String requestIgnoredDone = 'درخواست نادیده گرفته شد';

  // Chat: the server's refusals
  static const String chatRequestNotAccepted = 'تا پذیرفته شدن درخواستتان صبر کنید';
  static const String chatCannotReply = 'دیگر نمی‌توانید در این گفتگو پیام بفرستید';
  static const String chatMessageTooLong = 'پیام حداکثر ۱۰۰۰ نویسه است';
  static const String chatRequestMessageTooLong = 'پیام اول حداکثر ۵۰۰ نویسه است';
  static const String chatMessageEmpty = 'پیام خالی است';
  static const String chatConversationNotFound = 'گفتگو پیدا نشد';
  static const String chatCannotMessageSelf = 'نمی‌توانید به خودتان پیام بدهید';
  static const String chatTooManyRequests =
      'امروز گفتگوی جدید زیادی شروع کرده‌اید یا پیام زیادی فرستاده‌اید. کمی بعد دوباره تلاش کنید';

  // Notifications
  static const String notificationsTitle = 'اعلان‌ها';
  static const String notificationsEmptyTitle = 'اعلانی ندارید';
  static const String notificationsEmptySubtitle = 'خبرهای بازی‌ها، درخواست‌ها و جستجوهای ذخیره‌شده اینجا می‌آید.';
  static const String markAllRead = 'خواندن همه';
  static const String allMarkedRead = 'همه اعلان‌ها خوانده شد';
  static const String notificationNotFound = 'این اعلان دیگر در دسترس نیست';

  // Notifications: preferences
  static const String notificationSettingsTitle = 'تنظیمات اعلان‌ها';
  static const String pushSectionTitle = 'اعلان روی گوشی';
  static const String pushSectionHint =
      'خاموش کردن یک دسته فقط اعلان روی گوشی را قطع می‌کند؛ در صندوق اعلان‌ها همچنان می‌آید.';
  static const String pushMatches = 'بازی‌ها و درخواست‌ها';
  static const String pushChat = 'پیام‌ها';
  static const String pushRatings = 'امتیازدهی';
  static const String pushSavedSearches = 'جستجوهای ذخیره‌شده';
  static const String pushAccount = 'حساب کاربری';
  static const String pushAccountHint = 'هشدارها و اطلاعیه‌های حساب همیشه فرستاده می‌شوند.';
  static const String quietHoursTitle = 'ساعت سکوت';
  static const String quietHoursHint =
      'در این ساعت‌ها (به وقت تهران) اعلانی روی گوشی نمی‌آید، جز یادآوری بازی و خبر لغو یا تغییر بازی نزدیک.';
  static const String quietStart = 'از ساعت';
  static const String quietEnd = 'تا ساعت';
  static const String preferencesSaved = 'تنظیمات ذخیره شد';
  static const String quietHoursSame = 'شروع و پایان ساعت سکوت نمی‌تواند یکی باشد';
  static const String quietHoursInvalid = 'ساعت سکوت باید مضرب ۳۰ دقیقه باشد';

  // Catalog: city picker
  static const String cityPickerTitle = 'انتخاب شهر';
  static const String provinceSearchHint = 'جستجوی استان';
  static const String citySearchHint = 'جستجوی شهر';
  static const String changeProvince = 'تغییر استان';

  /// [count] in Persian digits.
  static String cityVenueCount(String count) => '$count باشگاه';

  // Catalog: venue picker
  static const String venuePickerTitle = 'انتخاب باشگاه';
  static const String venueSearchHint = 'جستجوی نام باشگاه';
  static const String venuesEmptyTitle = 'باشگاهی پیدا نشد';
  static const String venuesEmptySubtitle = 'نام دیگری را جستجو کنید';

  /// [max] in Persian digits.
  static String venueSelectionLimit(String max) => 'حداکثر $max باشگاه می‌توانید انتخاب کنید';

  /// [count] and [max] in Persian digits.
  static String venueConfirm(String count, String max) => 'تأیید ($count از $max)';

  /// A sport tag on a venue: «تنیس ۶ زمین». [count] in Persian digits.
  static String sportCourts(String sport, String count) => '$sport $count زمین';

  // Catalog: level picker
  static const String sportLevelTitle = 'سطح بازی';

  // Catalog: venue detail
  static const String venueTitle = 'باشگاه';
  static const String venueAddress = 'نشانی';
  static const String venuePhone = 'تلفن';
  static const String venueSports = 'رشته‌ها و زمین‌ها';
  static const String venueNoAddress = 'نشانی این باشگاه ثبت نشده است';
  static const String venueNotFound = 'این باشگاه پیدا نشد یا دیگر نمایش داده نمی‌شود';
  static const String venueMapLabel = 'موقعیت باشگاه روی نقشه';
  static const String courtsUnknown = 'تعداد زمین نامشخص';

  /// [count] in Persian digits.
  static String courtCount(String count) => '$count زمین';
  static const String courtIndoor = 'سرپوشیده';
  static const String courtOutdoor = 'روباز';
  static const String courtIndoorOutdoor = 'سرپوشیده و روباز';
  static const String courtLighting = 'نورپردازی شب';
  static const String surfaceHard = 'سخت';
  static const String surfaceClay = 'خاک رس';
  static const String surfaceGrass = 'چمن';
  static const String surfaceArtificialGrass = 'چمن مصنوعی';
  static const String surfaceCarpet = 'موکت';
  static const String surfaceWood = 'چوب';
  static const String surfaceSynthetic = 'مصنوعی';
  static const String surfaceGlass = 'شیشه';

  // Navigation shell: the bottom bar's tabs, right to left
  static const String navHome = 'خانه';
  static const String navSearch = 'جستجو';
  static const String navMatches = 'بازی‌های من';
  static const String navChat = 'گفتگوها';
  static const String navProfile = 'پروفایل';

  // Shared components
  /// A badge's spoken count; [count] in Persian digits.
  static String unreadCount(String count) => '$count مورد خوانده‌نشده';

  /// A step header; [step] and [total] in Persian digits.
  static String stepOf(String step, String total) => 'مرحله $step از $total';

  /// A progress bar's spoken value; [percent] in Persian digits.
  static String progressPercent(String percent) => 'پیشرفت $percent٪';

  /// A range from [start] to [end], as a level range reads.
  static String rangeFromTo(String start, String end) => 'از $start تا $end';
  static const String searchHint = 'جستجو';
  static const String clearSearch = 'پاک کردن جستجو';

  /// OpenStreetMap's licence asks for this credit on every map, in this form.
  static const String mapAttribution = '© OpenStreetMap contributors';

  // Redesign: home, search, availability, notifications
  static const String greetingMorning = 'صبح بخیر';
  static const String greetingNoon = 'ظهر بخیر';
  static const String greetingAfternoon = 'عصر بخیر';
  static const String greetingNight = 'شب بخیر';
  static const String homeReady = 'آماده‌ای بازی کنیم؟';

  /// [name] is the player's display name.
  static String homeReadyNamed(String name) => '$name، آماده‌ای بازی کنیم؟';
  static const String homeHeroEyebrow = 'هم‌بازی مناسب، همین نزدیکی';
  static const String homeHeroTitle = 'در سطح خودت،\nدر باشگاه خودت.';
  static const String homeHeroCta = 'پیدا کردن هم‌بازی';
  static const String quickActionsTitle = 'دسترسی سریع';
  static const String quickSearchCaption = 'بر اساس زمان آزاد';
  static const String quickPost = 'ثبت آگهی بازی';
  static const String quickPostCaption = 'بازیکن پیدا کن';
  static const String quickAvailability = 'زمان آزاد من';
  static const String quickAvailabilityCaption = 'بگویید کی آزادید';

  /// [count] in Persian digits.
  static String activeWindows(String count) => '$count بازه فعال';
  static const String nextGameTitle = 'بازی بعدی';
  static const String viewAll = 'مشاهده همه';
  static const String nextGameEmptyTitle = 'بازی پیش رویی ندارید';
  static const String nextGameEmptySubtitle = 'هم‌بازی پیدا کنید یا آگهی بازی بگذارید.';
  static const String pendingTitle = 'کارهای در انتظار';

  /// [host] is the host's display name.
  static String pendingInvitation(String host) => 'دعوت به بازی از $host';

  /// [count] in Persian digits.
  static String pendingRequests(String count) => '$count درخواست پیوستن';
  static const String pendingAttendance = 'بازی برگزار شد؟';
  static const String pendingRating = 'به هم‌بازی‌هایتان امتیاز دهید';
  static const String pendingMessages = 'پیام‌های تازه';

  /// [count] in Persian digits.
  static String unreadConversations(String count) => '$count گفتگو';

  /// [count] in Persian digits.
  static String unreadChatRequests(String count) => '$count درخواست گفتگو';

  /// [days] are the window's weekdays, «شنبه، دوشنبه».
  static String reconfirmDays(String days) => 'هنوز $days آزادید؟';
  static const String reconfirmTitle = 'هنوز در زمان‌های آزادتان آزادید؟';

  /// [date] is a Jalali date for reading, «۳۰ آبان ۱۴۰۵».
  static String reconfirmPausesOn(String date) => 'بازهٔ زمانی شما $date متوقف می‌شود.';

  /// Several windows: [date] is the first of their pause days.
  static String reconfirmPausesOnMany(String date) => 'بازه‌های زمانی شما از $date متوقف می‌شوند.';

  /// [date] is a Jalali date for reading. On an active weekly window's card.
  static String availabilityPausesOn(String date) => 'توقف خودکار: $date';
  static const String searchOpenPostsTitle = 'آگهی‌های باز';
  static const String searchOpenPostsSubtitle = 'نزدیک‌ترین زمان‌ها';
  static const String searchPlayersSubtitle = 'بر اساس هم‌پوشانی زمان آزاد';

  /// [count] in Persian digits.
  static String openSpotsShort(String count) => '$count جای خالی';

  /// [name] is the host's display name.
  static String postHost(String name) => 'میزبان: $name';
  static const String overlapBoxTitle = 'هم‌پوشانی زمان آزاد';
  static const String messageShort = 'پیام';
  static const String searchShowResults = 'نمایش نتایج';
  static const String unreadNotification = 'خوانده‌نشده';

  // Redesign: sign-in, onboarding, catalog
  /// How the brand mark on the sign-in art is read out.
  static const String brandName = 'رالیتو';
  static const String signInTagline = 'هم‌بازی هم‌سطح، در باشگاه و زمان دلخواه شما.';
  static const String signInTerms =
      'با ادامه، شرایط استفاده و حریم خصوصی را می‌پذیرید. استفاده فقط برای افراد بالای ۱۸ سال مجاز است.';
  static const String onboardingStepHint = 'این اطلاعات کمک می‌کند هم‌بازی مناسب‌تری پیدا کنید.';
  static const String genderLockedTitle = 'این انتخاب بعداً قابل تغییر نیست.';
  static const String provinceLabel = 'استان';
  static const String chooseProvince = 'انتخاب استان';

  /// A chosen home club's row, read out: tapping it takes the club off the list.
  static String homeVenueChosen(String venue) => '$venue، انتخاب‌شده. برای برداشتن لمس کنید';
  static const String venueCourtsStat = 'زمین';
  static const String venueSettingStat = 'فضا';
  static const String venueSurfaceStat = 'کف زمین';
  static const String venueStatUnknown = 'نامشخص';

  // Redesign: chat, profiles, reports
  /// A chat inbox segment with its unread count, «گفتگوها • ۳»; [count] in Persian digits.
  static String segmentWithCount(String label, String count) => '$label ($count)';
  static const String messageRequestLabel = 'درخواست پیام';
  static const String mutedConversation = 'بی‌صدا';
  static const String safetyBannerTitle = 'با خیال راحت بازی کنید';
  static const String messageAction = 'پیام';

  /// A sport profile's level box, «سطح متوسط»; [level] is the sport's own name for it.
  static String levelNamed(String level) => 'سطح $level';
  static const String factExperience = 'تجربه';
  static const String factFormat = 'فرمت';
  static const String factGoal = 'هدف';
  static const String favoriteClubsTitle = 'باشگاه‌های منتخب';
  static const String myReputationTitle = 'اعتبار و امتیازهای من';
  static const String reputationEmptyTitle = 'هنوز امتیازی ندارید';
  static const String reputationEmptySubtitle = 'بعد از هر بازی، هم‌بازی‌ها می‌توانند به شما امتیاز بدهند.';
  static const String sportProfilesTitle = 'پروفایل‌های ورزشی';
  static const String privacySafetyTitle = 'حریم خصوصی و امنیت';
  static const String profileCompletionTitle = 'تکمیل پروفایل';

  /// [percent] in Persian digits: «۸۰٪».
  static String percentLabel(String percent) => '$percent٪';
  static const String completionHintPhoto = 'با افزودن عکس، اعتماد بیشتری بسازید.';
  static const String completionHintBio = 'چند جمله درباره بازی‌تان بنویسید تا هم‌بازی‌ها شما را بهتر بشناسند.';
  static const String completionHintSports = 'ورزش و سطح بازی‌تان را اضافه کنید.';
  static const String completionHintHomeVenues = 'باشگاه‌هایی را که در آن‌ها بازی می‌کنید انتخاب کنید.';

  /// The report details' counter; [count] and [max] in Persian digits.
  static String reportDetailsCount(String count, String max) => '$count از $max';

  // Account deletion
  static const String deleteAccount = 'حذف حساب کاربری';
  static const String deleteAccountQuestion = 'حساب کاربری‌تان حذف شود؟';
  static const String deleteAccountIntro = 'با حذف حساب:';
  static const String deleteAccountAnonymised =
      'نام، عکس و اطلاعات پروفایل شما ناشناس می‌شود و دیگر در جستجو دیده نمی‌شوید.';
  static const String deleteAccountGames = 'از بازی‌های آینده خارج می‌شوید و بازی‌هایی که میزبانشان هستید لغو می‌شوند.';
  static const String deleteAccountMessages = 'پیام‌هایتان در گفتگوها با نام «کاربر حذف‌شده» باقی می‌ماند.';
  static const String deleteAccountIrreversible = 'این کار برگشت‌پذیر نیست.';
  static const String deleteAccountCodeHint = 'برای تأیید، یک کد به شمارهٔ شما پیامک می‌شود.';
  static const String deleteAccountContinue = 'ادامه و دریافت کد';
  static const String deleteAccountCodeTitle = 'تأیید حذف حساب';
  static const String deleteAccountCodeHeading = 'کد تأیید را وارد کنید';
  static const String deleteAccountCodeSent = 'کد ۴ رقمی به شمارهٔ شما پیامک شد.';
  static const String deleteAccountSending = 'در حال ارسال کد تأیید…';
  static const String deleteAccountNotSent = 'کد ارسال نشد. کمی بعد دوباره درخواست کنید.';
  static const String deleteAccountGetCode = 'دریافت کد';
  static const String deleteAccountConfirm = 'حذف همیشگی حساب';
  static const String deleteAccountWarning = 'پس از تأیید، حساب شما بی‌درنگ حذف می‌شود و برنمی‌گردد.';
  static const String accountDeletedTitle = 'حساب حذف شد';
  static const String accountDeletedNotice = 'حساب کاربری شما حذف شد. هر وقت خواستید می‌توانید دوباره ثبت‌نام کنید.';
  static const String deletionCodeInvalid = 'کد واردشده درست نیست.';
  static const String deletionCodeExpired = 'کد منقضی شده است. کد جدید بگیرید.';
  static const String deletionTooSoon = 'کمی صبر کنید و دوباره درخواست کد بدهید.';
  static const String deletionTooMany = 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.';
}
