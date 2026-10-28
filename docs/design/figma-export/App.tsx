import { useState, type ReactNode } from 'react'

type Screen =
  | 'home'
  | 'search'
  | 'player'
  | 'invite'
  | 'post'
  | 'match'
  | 'matches'
  | 'chats'
  | 'conversation'
  | 'profile'
  | 'system'
  | 'signin'
  | 'onboarding'

const fa = (value: string | number) =>
  String(value).replace(/\d/g, (digit) => '۰۱۲۳۴۵۶۷۸۹'[Number(digit)])

function Icon({ name }: { name: string }) {
  const paths: Record<string, ReactNode> = {
    home: <><path d="m3 10 9-7 9 7v9a2 2 0 0 1-2 2h-4v-7H9v7H5a2 2 0 0 1-2-2Z" /></>,
    search: <><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></>,
    games: <><path d="M6 4v3M18 4v3M4 9h16M5 6h14a1 1 0 0 1 1 1v13H4V7a1 1 0 0 1 1-1Z" /><path d="m9 15 2 2 4-5" /></>,
    chat: <><path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4Z" /></>,
    user: <><circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" /></>,
    bell: <><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9ZM10 21h4" /></>,
    arrow: <><path d="m15 18-6-6 6-6" /></>,
    plus: <><path d="M12 5v14M5 12h14" /></>,
    clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>,
    pin: <><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z" /><circle cx="12" cy="10" r="2" /></>,
    star: <><path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9Z" /></>,
    filter: <><path d="M4 6h16M7 12h10M10 18h4" /></>,
    shield: <><path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z" /><path d="m9 12 2 2 4-5" /></>,
    send: <><path d="m22 2-7 20-4-9-9-4Z" /><path d="M22 2 11 13" /></>,
  }
  return <svg className="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>{paths[name]}</svg>
}

function Button({ children, onClick, variant = 'primary', icon }: { children: ReactNode; onClick?: () => void; variant?: 'primary' | 'secondary' | 'ghost' | 'danger'; icon?: string }) {
  return <button className={`button ${variant}`} onClick={onClick}>{icon && <Icon name={icon} />}<span>{children}</span></button>
}

function Chip({ children, active, tone }: { children: ReactNode; active?: boolean; tone?: 'green' | 'orange' | 'red' }) {
  return <span className={`chip ${active ? 'active' : ''} ${tone || ''}`}>{children}</span>
}

function Avatar({ name = 'سام', large }: { name?: string; large?: boolean }) {
  return <div className={`avatar ${large ? 'large' : ''}`}>{name.slice(0, 1)}</div>
}

function Header({ title, back, action }: { title: string; back?: () => void; action?: ReactNode }) {
  return <header className="topbar">{back ? <button className="icon-button" onClick={back}><Icon name="arrow" /></button> : <div className="brand-mark">ت</div>}<strong>{title}</strong><div className="header-action">{action}</div></header>
}

function BottomNav({ screen, go }: { screen: Screen; go: (s: Screen) => void }) {
  const items: [Screen, string, string][] = [['home', 'خانه', 'home'], ['search', 'جستجو', 'search'], ['matches', 'بازی‌های من', 'games'], ['chats', 'گفتگوها', 'chat'], ['profile', 'پروفایل', 'user']]
  return <nav className="bottom-nav">{items.map(([id, label, icon]) => <button key={id} className={screen === id ? 'selected' : ''} onClick={() => go(id)}><span className="nav-icon"><Icon name={icon} />{id === 'chats' && <b>۳</b>}</span><small>{label}</small></button>)}</nav>
}

function GameCard({ onClick, status = 'قطعی' }: { onClick: () => void; status?: string }) {
  return <button className="card game-card" onClick={onClick}>
    <div className="row between"><div className="sport-ball">T</div><div className="grow"><strong>تنیس در استقلال</strong><p>شنبه، ۲ آبان · ۱۹:۰۰ تا ۲۰:۳۰</p></div><Chip tone={status === 'قطعی' ? 'green' : 'orange'}>{status}</Chip></div>
    <div className="meta"><span><Icon name="pin" /> مجموعه تنیس استقلال</span><span>متوسط · یک‌نفره</span></div>
    <div className="avatars"><Avatar name="س" /><Avatar name="ع" /><span>شما و علی رضایی</span></div>
  </button>
}

function Home({ go }: { go: (s: Screen) => void }) {
  return <><div className="home-head"><div><span className="eyebrow">عصر بخیر</span><h1>سام، آماده‌ای بازی کنیم؟</h1></div><button className="icon-button notification"><Icon name="bell" /><b>۲</b></button></div>
    <section className="hero">
      <div><span className="eyebrow light">هم‌بازی مناسب، همین نزدیکی</span><h2>در سطح خودت،<br />در باشگاه خودت.</h2></div>
      <div className="court-lines" aria-hidden><i /><i /><span /></div>
      <Button onClick={() => go('search')}>پیدا کردن هم‌بازی</Button>
    </section>
    <section><div className="section-title"><h2>دسترسی سریع</h2></div><div className="quick-grid">
      <button onClick={() => go('search')}><span><Icon name="search" /></span><b>جستجوی هم‌بازی</b><small>بر اساس زمان آزاد</small></button>
      <button onClick={() => go('post')}><span className="orange"><Icon name="plus" /></span><b>ثبت آگهی بازی</b><small>بازیکن پیدا کن</small></button>
      <button><span className="blue"><Icon name="clock" /></span><b>زمان آزاد من</b><small>۲ بازه فعال</small></button>
    </div></section>
    <section><div className="section-title"><h2>بازی بعدی</h2><button>مشاهده همه</button></div><GameCard onClick={() => go('match')} /></section>
    <section><div className="notice-card"><div className="notice-icon"><Icon name="clock" /></div><div><strong>هنوز شنبه‌ها آزادید؟</strong><p>بازهٔ زمانی شما ۲ روز دیگر متوقف می‌شود.</p></div><Button variant="secondary">هنوز آزادم</Button></div></section>
  </>
}

function Search({ go }: { go: (s: Screen) => void }) {
  const [filters, setFilters] = useState(false)
  return <><Header title="جستجوی هم‌بازی" action={<button className="icon-button" onClick={() => setFilters(!filters)}><Icon name="filter" /></button>} />
    <div className="searchbox"><Icon name="search" /><span>نام بازیکن یا باشگاه</span></div>
    <div className="chips-row"><Chip active>تنیس</Chip><Chip active>شنبه · ۱۸ تا ۲۲</Chip><Chip>متوسط ±۱</Chip></div>
    {filters && <div className="sheet inline-sheet"><span className="handle" /><div className="section-title"><h2>فیلترها</h2><button onClick={() => setFilters(false)}>بستن</button></div><Field label="شهر" value="تهران" /><Label text="روزهای هفته" /><div className="chips-row wrap">{['شنبه','یکشنبه','دوشنبه','سه‌شنبه','چهارشنبه'].map(x=><Chip active={x==='شنبه'}>{x}</Chip>)}</div><Label text="نوع نتیجه" /><Segment items={['هر دو','بازیکن','آگهی']} /><Button onClick={() => setFilters(false)}>نمایش ۲۴ نتیجه</Button></div>}
    <div className="section-title"><div><h2>آگهی‌های باز</h2><p>نزدیک‌ترین زمان‌ها</p></div><button>همه</button></div>
    <button className="card open-post" onClick={() => go('match')}><div className="row between"><Chip tone="orange">۲ جای خالی</Chip><strong>تنیس · دونفره</strong></div><h3>امشب در باشگاه استقلال</h3><div className="meta"><span><Icon name="clock" /> امروز، ۱۹:۳۰</span><span>متوسط تا پیشرفته</span></div><div className="row between"><span className="host"><Avatar name="م" /> میزبان: مهدی</span><span className="link">درخواست پیوستن</span></div></button>
    <div className="section-title"><div><h2>بازیکن‌ها</h2><p>بر اساس هم‌پوشانی زمان آزاد</p></div></div>
    <button className="card player-card" onClick={() => go('player')}><div className="row"><Avatar name="ع" large /><div className="grow"><div className="row between"><h3>علی رضایی</h3><Chip tone="green">خوش‌قولی: عالی</Chip></div><p>۲۵–۳۴ سال · متوسط · ۱ تا ۳ سال</p><span className="rating"><Icon name="star" /> ۴٫۸ <small>(۱۸ امتیاز)</small></span></div></div><div className="overlap"><Icon name="clock" /><div><b>هم‌پوشانی زمان آزاد</b><p>شنبه‌ها ۱۸:۰۰–۲۰:۳۰، باشگاه استقلال</p></div></div><div className="card-actions"><Button variant="secondary">پیام</Button><Button onClick={() => go('invite')}>دعوت به بازی</Button></div></button>
    <Button variant="secondary">نتایج بیشتر</Button>
  </>
}

function Label({ text }: { text: string }) { return <label className="label">{text}</label> }
function Field({ label, value, hint }: { label: string; value: string; hint?: string }) { return <div className="field"><Label text={label} /><div className="input">{value}<Icon name="arrow" /></div>{hint && <small>{hint}</small>}</div> }
function Segment({ items }: { items: string[] }) { return <div className="segment">{items.map((x, i) => <button className={i === 0 ? 'active' : ''}>{x}</button>)}</div> }

function Player({ go }: { go: (s: Screen) => void }) {
  return <><Header title="پروفایل بازیکن" back={() => go('search')} action={<button className="icon-button">•••</button>} />
    <div className="profile-hero"><Avatar name="ع" large /><h1>علی رضایی</h1><p>۲۵–۳۴ سال · تهران · فعال امروز</p><Chip tone="green"><Icon name="shield" /> خوش‌قولی: عالی</Chip></div>
    <div className="bio">«تنیس را جدی اما دوستانه بازی می‌کنم. معمولاً عصرهای آخر هفته آزاد هستم.»</div>
    <section className="card"><div className="row between"><h2>تنیس</h2><span className="rating"><Icon name="star" /> ۴٫۸ <small>از ۱۸ نفر</small></span></div><div className="level"><b>سطح متوسط</b><p>رالی پایدار دارد و سرویس را با کنترل مناسب اجرا می‌کند.</p></div><div className="facts"><span>تجربه <b>۱ تا ۳ سال</b></span><span>فرمت <b>یک‌نفره، دونفره</b></span><span>هدف <b>بازی دوستانه</b></span></div><div className="tags"><Chip>وقت‌شناس</Chip><Chip>رالی خوب</Chip><Chip>خوش‌برخورد</Chip></div><p className="statement">بیشتر هم‌بازی‌ها می‌گویند در سطح اعلام‌شده بازی می‌کند.</p></section>
    <section><div className="section-title"><h2>باشگاه‌های منتخب</h2></div><div className="list-row"><Icon name="pin" /><div><b>مجموعه تنیس استقلال</b><p>تهران، میدان ونک</p></div></div></section>
    <div className="sticky-actions"><Button variant="secondary">پیام</Button><Button onClick={() => go('invite')}>دعوت به بازی</Button></div>
  </>
}

function Invite({ go }: { go: (s: Screen) => void }) {
  return <><Header title="دعوت به بازی" back={() => go('player')} /><div className="invitee"><Avatar name="ع" /><div><b>دعوت از علی رضایی</b><p>تنیس · سطح متوسط</p></div></div><Label text="انتخاب بازی" /><div className="card selected-game"><span className="radio" /><div><b>شنبه در باشگاه استقلال</b><p>۲ آبان · ۱۹:۰۰ تا ۲۰:۳۰</p></div><Chip tone="green">باز</Chip></div><button className="new-game"><Icon name="plus" /> ساخت بازی جدید</button><div className="field"><Label text="پیام (اختیاری)" /><textarea placeholder="سلام علی، برای بازی شنبه وقت داری؟" maxLength={200} /><small>۰ از ۲۰۰</small></div><div className="info"><Icon name="shield" /><p>شماره تماس شما نمایش داده نمی‌شود. هماهنگی را در تنیس‌یار انجام دهید.</p></div><Button onClick={() => go('match')} icon="send">ارسال دعوت</Button></>
}

function Match({ go }: { go: (s: Screen) => void }) {
  const [host, setHost] = useState(false)
  const [confirmed, setConfirmed] = useState(false)
  return <><Header title="جزئیات بازی" back={() => go(host ? 'home' : 'search')} action={<button className="icon-button">•••</button>} />
    <div className="match-cover"><div className="row between"><span className="sport-label">تنیس · یک‌نفره</span><Chip tone={confirmed ? 'green' : 'orange'}>{confirmed ? 'قطعی' : 'باز'}</Chip></div><h1>بازی عصر شنبه</h1><div className="match-info"><span><Icon name="pin" /> مجموعه تنیس استقلال</span><span><Icon name="clock" /> شنبه ۱۴۰۵/۰۸/۰۲، ۱۹:۰۰ تا ۲۰:۳۰</span></div></div>
    <div className="stat-grid"><div><small>مدت</small><b>۹۰ دقیقه</b></div><div><small>سطح</small><b>متوسط ±۱</b></div><div><small>زمین</small><b>رزرو شده</b></div></div>
    <section><div className="section-title"><h2>بازیکن‌ها · ۲ از ۲</h2><button onClick={() => setHost(!host)}>{host ? 'نمای مهمان' : 'نمای میزبان'}</button></div><div className="list-row"><Avatar name="م" /><div className="grow"><b>مهدی نوری <Chip>میزبان</Chip></b><p>متوسط · خوش‌قولی: عالی</p></div></div><div className="list-row"><Avatar name="ع" /><div className="grow"><b>علی رضایی</b><p>{host ? 'درخواست داده · خارج از بازه سطح' : 'دعوت‌شده'}</p></div>{host && !confirmed && <div className="mini-actions"><button>رد</button><button onClick={() => setConfirmed(true)}>پذیرش</button></div>}</div></section>
    <section className="card details"><h2>درباره بازی</h2><p>یک بازی دوستانه و منظم. لطفاً ۱۵ دقیقه زودتر در باشگاه باشید.</p><div className="cost"><span>هزینه تقریبی هر نفر</span><b>۳۵۰٬۰۰۰ تومان</b></div></section>
    {confirmed ? <><div className="success-banner"><Icon name="shield" /><div><b>بازی قطعی شد</b><p>هر دو بازیکن حضورشان را تأیید کرده‌اند.</p></div></div><Button onClick={() => go('conversation')} variant="secondary">گفتگوی بازی</Button></> : host ? <div className="sticky-actions"><Button variant="secondary">دعوت بازیکن</Button><Button onClick={() => setConfirmed(true)}>قطعی کردن زودتر</Button></div> : <><div className="warning">لغو بازی قطعی کمتر از ۱۲ ساعت مانده به شروع، روی خوش‌قولی شما اثر می‌گذارد.</div><Button onClick={() => setConfirmed(true)}>پذیرفتن دعوت</Button><Button variant="ghost">رد کردن</Button></>}
  </>
}

function Post({ go }: { go: (s: Screen) => void }) {
  return <><Header title="ثبت آگهی بازی" back={() => go('home')} /><div className="progress"><span style={{width:'55%'}} /></div><p className="step">جزئیات بازی · مرحله ۲ از ۳</p><Field label="ورزش" value="تنیس" /><Label text="فرمت بازی" /><Segment items={['یک‌نفره','دونفره']} /><Field label="باشگاه" value="مجموعه تنیس استقلال" /><div className="two-col"><Field label="تاریخ" value="۱۴۰۵/۰۸/۰۲" /><Field label="شروع" value="۱۹:۰۰" /></div><Field label="مدت بازی" value="۹۰ دقیقه" /><Label text="سطح هم‌بازی" /><div className="range"><b>متوسط رو به پایین</b><span /><b>پیشرفته</b></div><div className="toggle-row"><div><b>زمین رزرو شده است</b><p>فقط وضعیت رزرو را اعلام می‌کنید.</p></div><button className="switch on"><i /></button></div><div className="open-spots">این آگهی <b>۱ جای خالی</b> خواهد داشت.</div><Button onClick={() => go('match')}>انتشار آگهی</Button></>
}

function Matches({ go }: { go: (s: Screen) => void }) {
  return <><Header title="بازی‌های من" /><Segment items={['پیش‌رو · ۳','گذشته']} /><div className="state-tabs"><Chip active>همه</Chip><Chip>قطعی</Chip><Chip>در انتظار</Chip></div><GameCard onClick={() => go('match')} /><GameCard onClick={() => go('match')} status="در انتظار" /><div className="paste-link"><Icon name="games" /><div><b>لینک بازی دارید؟</b><p>لینک اشتراک‌گذاری‌شده را باز کنید.</p></div><button>چسباندن</button></div></>
}

function Chats({ go }: { go: (s: Screen) => void }) {
  return <><Header title="گفتگوها" /><Segment items={['گفتگوها · ۳','درخواست‌ها · ۱']} /><button className="chat-row" onClick={() => go('conversation')}><Avatar name="ع" /><div className="grow"><div className="row between"><b>علی رضایی</b><small>۱۰:۴۲</small></div><p>عالیه، شنبه می‌بینمت.</p></div><span className="unread">۲</span></button><button className="chat-row" onClick={() => go('conversation')}><div className="group-avatar">T</div><div className="grow"><div className="row between"><b>تنیس · مجموعه استقلال</b><small>دیروز</small></div><p>مهدی: زمین شماره ۴ رزرو شد.</p></div></button><div className="request-card"><div className="row"><Avatar name="ر" /><div><b>رضا کاظمی</b><p>درخواست پیام · متوسط</p></div></div><p>سلام، برای بازی سه‌شنبه در انقلاب وقت دارید؟</p><div className="card-actions"><Button variant="ghost">نادیده گرفتن</Button><Button onClick={() => go('conversation')}>پذیرفتن</Button></div></div></>
}

function Conversation({ go }: { go: (s: Screen) => void }) {
  const [sent, setSent] = useState(false)
  return <><Header title="علی رضایی" back={() => go('chats')} action={<button className="icon-button">•••</button>} /><div className="safety"><Icon name="shield" /><p><b>با خیال راحت بازی کنید</b><br />فقط در باشگاه قرار بگذارید و اطلاعات شخصی را به اشتراک نگذارید.</p></div><div className="date-separator">شنبه، ۲ آبان</div><div className="messages"><div className="bubble theirs">سلام سام، برای بازی شنبه آماده‌ای؟<small>۱۰:۳۴</small></div><div className="bubble mine">سلام، بله حتماً. ساعت ۱۹ عالیه.<small>۱۰:۳۸ · خوانده شد</small></div><div className="bubble theirs">عالیه، شنبه می‌بینمت.<small>۱۰:۴۲</small></div>{sent && <div className="bubble mine">تا شنبه، ممنون.<small>اکنون · در حال ارسال</small></div>}</div><div className="composer"><button className="icon-button"><Icon name="plus" /></button><div className="input">پیام بنویسید…</div><button className="send-button" onClick={() => setSent(true)}><Icon name="send" /></button></div></>
}

function Profile({ go }: { go: (s: Screen) => void }) {
  return <><Header title="پروفایل من" action={<button className="link">ویرایش</button>} /><div className="profile-hero compact"><Avatar name="س" large /><h1>سام احمدی</h1><p>تهران · عضو از فروردین ۱۴۰۴</p><Chip tone="green">خوش‌قولی: خوب</Chip></div><div className="profile-completion"><div className="row between"><b>تکمیل پروفایل</b><span>۸۰٪</span></div><div className="bar"><i /></div><p>با افزودن عکس، اعتماد بیشتری بسازید.</p></div><section className="menu"><button><Icon name="star" /><span>اعتبار و امتیازهای من</span><Icon name="arrow" /></button><button><Icon name="games" /><span>پروفایل‌های ورزشی</span><Icon name="arrow" /></button><button><Icon name="pin" /><span>باشگاه‌های منتخب</span><Icon name="arrow" /></button><button><Icon name="bell" /><span>تنظیمات اعلان‌ها</span><Icon name="arrow" /></button><button onClick={() => go('system')}><Icon name="shield" /><span>سیستم طراحی و حالت‌ها</span><Icon name="arrow" /></button></section><Button variant="secondary" onClick={() => go('signin')}>مشاهده مسیر ورود</Button></>
}

function DesignSystem({ go }: { go: (s: Screen) => void }) {
  return <><Header title="سیستم طراحی" back={() => go('profile')} /><p className="lead">رابطی آرام، ورزشی و قابل اعتماد برای تصمیم‌گیری سریع.</p><section><div className="section-title"><h2>رنگ‌ها</h2></div><div className="swatches"><span className="swatch primary">اصلی</span><span className="swatch accent">تأکید</span><span className="swatch success">موفق</span><span className="swatch warning-c">هشدار</span><span className="swatch error">خطا</span></div></section><section><div className="section-title"><h2>تایپوگرافی</h2></div><div className="type-sample"><h1>عنوان نمایش</h1><h2>عنوان بخش</h2><b>متن تأکیدی</b><p>متن بدنه برای توضیحات و اطلاعات کاربردی.</p><small>متن کمکی و برچسب‌ها</small></div></section><section><div className="section-title"><h2>اجزا</h2></div><div className="component-stack"><Button>دکمه اصلی</Button><Button variant="secondary">دکمه ثانویه</Button><Field label="ورودی متن" value="مقدار واردشده" /><div className="chips-row"><Chip active>انتخاب‌شده</Chip><Chip>عادی</Chip><Chip tone="orange">هشدار</Chip></div><div className="success-banner"><Icon name="shield" /><div><b>عملیات موفق بود</b><p>تغییرات شما ذخیره شد.</p></div></div><div className="error-banner">خطایی رخ داد. دوباره تلاش کنید.</div><div className="skeleton"><i/><i/><i/></div></div></section></>
}

function SignIn({ go }: { go: (s: Screen) => void }) {
  const [code, setCode] = useState(false)
  return <div className="auth"><div className="auth-art"><div className="brand-big">ت</div><div className="court-lines"><i/><i/><span/></div></div><h1>{code ? 'کد تأیید را وارد کنید' : 'به تنیس‌یار خوش آمدید'}</h1><p>{code ? 'کد ۴ رقمی به ۰۹۱۲•••۴۵۶۷ ارسال شد.' : 'هم‌بازی هم‌سطح، در باشگاه و زمان دلخواه شما.'}</p>{code ? <><div className="otp">{[1,2,3,4].map((x)=><input key={x} inputMode="numeric" maxLength={1} />)}</div><button className="link">ارسال دوباره تا ۰۰:۵۹</button><Button onClick={() => go('onboarding')}>ادامه</Button></> : <><div className="field"><Label text="شماره موبایل" /><div className="input ltr">۰۹۱۲ ۱۲۳ ۴۵۶۷</div></div><Button onClick={() => setCode(true)}>دریافت کد</Button><small className="terms">با ادامه، شرایط استفاده و حریم خصوصی را می‌پذیرید. استفاده فقط برای افراد بالای ۱۸ سال مجاز است.</small></>}</div>
}

function Onboarding({ go }: { go: (s: Screen) => void }) {
  const [step, setStep] = useState(1)
  const titles = ['چه صدایتان کنیم؟','جنسیت شما','تاریخ تولد','کجا بازی می‌کنید؟','ورزش و سطح شما','باشگاه‌های منتخب']
  return <div className="onboarding"><Header title={`مرحله ${fa(step)} از ۶`} /><div className="progress"><span style={{width:`${step/6*100}%`}} /></div><h1>{titles[step-1]}</h1><p>این اطلاعات کمک می‌کند هم‌بازی مناسب‌تری پیدا کنید.</p>{step===1&&<Field label="نام نمایشی" value="سام احمدی" hint="۲ تا ۳۰ نویسه" />}{step===2&&<><Segment items={['مرد','زن']} /><div className="info">این انتخاب بعداً قابل تغییر نیست.</div></>}{step===3&&<div className="three-col"><Field label="روز" value="۱۲" /><Field label="ماه" value="مهر" /><Field label="سال" value="۱۳۷۳" /></div>}{step===4&&<><Field label="استان" value="تهران" /><Field label="شهر" value="تهران" /></>}{step===5&&<><div className="chips-row"><Chip active>تنیس</Chip><Chip>پدل</Chip><Chip>بدمینتون</Chip><Chip>اسکواش</Chip></div><div className="level-card selected"><b>متوسط</b><p>رالی پایدار دارید و سرویس را با کنترل مناسب اجرا می‌کنید.</p></div><Field label="تجربه" value="۱ تا ۳ سال" /></>}{step===6&&<><div className="list-row"><Icon name="pin"/><div><b>مجموعه تنیس استقلال</b><p>تنیس، پدل</p></div><span className="check">✓</span></div><div className="list-row"><Icon name="pin"/><div><b>مجموعه ورزشی انقلاب</b><p>تنیس، اسکواش</p></div></div></>}<div className="onboarding-action"><Button onClick={() => step < 6 ? setStep(step+1) : go('home')}>{step < 6 ? 'ادامه' : 'شروع تنیس‌یار'}</Button>{step===6&&<Button variant="ghost" onClick={()=>go('home')}>فعلاً نه</Button>}</div></div>
}

export default function App() {
  const [screen, setScreen] = useState<Screen>('home')
  const bare = ['signin','onboarding'].includes(screen)
  const content: Record<Screen, ReactNode> = {
    home:<Home go={setScreen}/>, search:<Search go={setScreen}/>, player:<Player go={setScreen}/>, invite:<Invite go={setScreen}/>, post:<Post go={setScreen}/>, match:<Match go={setScreen}/>, matches:<Matches go={setScreen}/>, chats:<Chats go={setScreen}/>, conversation:<Conversation go={setScreen}/>, profile:<Profile go={setScreen}/>, system:<DesignSystem go={setScreen}/>, signin:<SignIn go={setScreen}/>, onboarding:<Onboarding go={setScreen}/>,
  }
  return <main dir="rtl" className={`app ${bare ? 'bare' : ''}`}><div className="content">{content[screen]}</div>{!bare && <BottomNav screen={screen} go={setScreen}/>}</main>
}
