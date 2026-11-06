#!/usr/bin/perl
# Builds /en/ English mirror of Sleepdienst Janssen + adds hreflang/lang switcher to NL pages.
#   perl build.pl && perl build-en.pl
use strict; use warnings; use utf8; use Encode;
use FindBin qw($Bin);
binmode STDOUT, ':utf8';

my $ROOT  = $Bin;
my $SITE  = 'https://sleepdienstjanssen.nl';
my $NAME  = 'Janssen Towing';
my $NAME_NL = 'Sleepdienst Janssen';
my $DISP  = '0970 1022 9095';
my $TEL   = '+3197010229095';
my $WA    = 'https://wa.me/3197010229095';
my @t = localtime; my $TODAY = sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3];

sub rd { my $f = shift; open my $h, '<:raw', $f or die "$f: $!"; local $/; my $s = decode('UTF-8', scalar <$h>); $s =~ s/\r\n/\n/g; $s }
sub wr {
  my ($rel, $s) = @_; my $f = "$ROOT/$rel";
  (my $d = $f) =~ s{/[^/]*$}{}; my $p = '';
  for (split m{/}, $d) { $p .= "$_/"; mkdir $p unless -d $p }
  $s =~ s/\n/\r\n/g unless $rel =~ /\.xml$/;
  open my $h, '>:raw', $f or die "$f: $!"; print $h encode('UTF-8', $s); close $h;
}
sub esc { my $s = shift // ''; $s =~ s/&(?!#?\w+;)/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; $s =~ s/'/&#x27;/g; $s }
sub typo { my $s = shift // ''; $s =~ s/'/&rsquo;/g; $s }
sub plain { my $s = shift // ''; $s =~ s/<[^>]+>//g; $s =~ s/&rsquo;/'/g; $s =~ s/&amp;/&/g; $s =~ s/\s+/ /g; $s }
sub js { my $s = shift // ''; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; qq("$s") }

sub parse {
  my ($dir, $file) = @_; my @out; my $cur;
  for my $l (split /\n/, rd("$ROOT/$dir/$file")) {
    next if $l =~ /^\s*(#.*)?$/;
    if ($l =~ /^@\@(\w+) (\S+)$/) { $cur = { kind => $1, slug => $2 }; push @out, $cur; next }
    $l =~ /^(\w+): (.*)$/ or die "$file: bad line: $l\n";
    my ($k, $v) = ($1, $2);
    if ($k =~ /^(road|local|faq|html|check)$/) { push @{ $cur->{$k} }, $v } else { $cur->{$k} = $v }
  }
  @out;
}

my @TOWNS; push @TOWNS, parse('src/pages-en', $_) for qw(towns-hub.txt towns-rijnmond.txt towns-drecht.txt towns-brabant.txt towns-zeeland.txt);
my @SERVICES = parse('src/pages-en', 'diensten.txt');
my %PLACE = map { $_->{slug} => $_ } @TOWNS;

my @FOOT_TOWNS = qw(rotterdam eindhoven barendrecht breda dordrecht tilburg den-bosch schiedam rotterdam-zuid gorinchem);
my $ART = rd("$ROOT/src/art-truck.svg"); $ART =~ s/\s+$//;
my $WAVE = '<svg class="wave" viewBox="0 0 1440 120" preserveAspectRatio="none" aria-hidden="true"><path d="M0 70 C 240 130, 480 10, 760 50 S 1220 120, 1440 30 L1440 120 L0 120Z" fill="#fff"/></svg>';

sub en_path {
  my $nl = shift; # e.g. /sleepdienst-rotterdam/ or /
  return '/en/' if $nl eq '/' || $nl eq '';
  $nl = "/$nl" unless $nl =~ m{^/};
  $nl .= '/' unless $nl =~ m{/$};
  return "/en$nl";
}
sub nl_path_from_en {
  my $en = shift;
  $en =~ s{^/en}{};
  $en = '/' if $en eq '' || $en eq '/';
  $en .= '/' unless $en =~ m{/$} || $en eq '/';
  $en;
}

sub lang_switcher {
  my ($nl_path, $cur) = @_; # cur = nl|en
  my $en = en_path($nl_path);
  my $nl = $nl_path;
  $nl = '/' if $nl eq '';
  if ($cur eq 'en') {
    return qq(<div class="lang" aria-label="Language"><a href="$nl" hreflang="nl" lang="nl">NL</a><span aria-hidden="true"> | </span><strong lang="en">EN</strong></div>);
  }
  return qq(<div class="lang" aria-label="Taal"><strong lang="nl">NL</strong><span aria-hidden="true"> | </span><a href="$en" hreflang="en" lang="en">EN</a></div>);
}

sub hreflang_tags {
  my ($nl_path) = @_;
  my $en = en_path($nl_path);
  my $nl = $nl_path; $nl = '/' if $nl eq '';
  qq(<link rel="alternate" hreflang="nl-NL" href="$SITE$nl">\n<link rel="alternate" hreflang="en" href="$SITE$en">\n<link rel="alternate" hreflang="x-default" href="$SITE$nl">\n);
}

sub card {
  my $s = shift; my $c = $PLACE{$s} or die "unknown place: $s\n";
  my $n = esc($c->{name});
  qq(<a class="city" href="/en/sleepdienst-$s/"><svg><use href="#i-pin"/></svg><span><b>Towing $n</b><small>).esc($c->{prov}).qq(</small></span></a>);
}
sub svc_card {
  my $s = shift;
  qq(<a class="city" href="/en/$s->{slug}/"><svg><use href="#i-truck"/></svg><span><b>).esc($s->{crumb}).qq(</b><small>).esc($s->{cardsub}).qq(</small></span></a>);
}

my $FOOT_WERK = join '', map { qq(<li><a href="/en/sleepdienst-$_/">Towing ).esc($PLACE{$_}{name}).qq(</a></li>) } grep { $PLACE{$_} } @FOOT_TOWNS;
$FOOT_WERK .= '<li><a href="/en/werkgebied/"><b>All locations</b></a></li>';
my $FOOT_SVC = join '', map { qq(<li><a href="/en/$_->{slug}/">).esc($_->{crumb}).'</a></li>' } @SERVICES;
$FOOT_SVC .= '<li><a href="/en/pech-op-de-snelweg/">Breakdown on the motorway</a></li><li><a href="/en/elektrische-auto-slepen/">Towing an electric car</a></li>';

# Shell from Dordrecht template, then rewrite chrome to EN
my $TPL = rd("$ROOT/sleepdienst-dordrecht/index.html");
my ($HEAD_TPL, $BODY_TOP) = $TPL =~ m{^(.*?</head>\n)(.*?)<nav class="crumbs}s or die 'shell top';
my ($FOOT_HTML) = $TPL =~ m{(</main>.*)$}s or die 'shell foot';
my ($ICONS) = $BODY_TOP =~ m{(<svg width="0".*?</svg>)}s;

# EN header/nav/footer/cta/steps
my $EN_TOPBAR = qq(<div class="topbar"><div class="container">
  <span><svg><use href="#i-clock"/></svg>24/7 help</span>
  <span><svg><use href="#i-pin"/></svg>Rotterdam, Drechtsteden, Brabant &amp; Zeeland</span>
  <span><svg><use href="#i-bolt"/></svg>Quickly on site</span>
</div></div>
);
my $EN_HEADER = qq(<header class="navwrap" id="nav">
  <nav class="container">
    <a class="logo" href="/en/" aria-label="Janssen Towing — home">
      <svg><use href="#i-logo"/></svg>
      <span><b>janssen <em>towing</em></b><small>When you need us</small></span>
    </a>
    <ul class="navlinks" id="navlinks">
      <li><a href="/en/#services">Services</a></li>
      <li><a href="/en/werkgebied/">Service area</a></li>
      <li><a href="/en/#how">How it works</a></li>
      <li><a href="/en/#faq">FAQ</a></li>
      <li><a href="#contact">Contact</a></li>
    </ul>
    <div class="navcta">
      LANGSWITCH
      <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call: $DISP</a>
      <a class="btn btn-navy" href="#contact">Request help</a>
    </div>
    <button class="burger" id="burger" aria-label="Open menu" aria-expanded="false" aria-controls="navlinks">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M3 6h18M3 12h18M3 18h18"/></svg>
    </button>
  </nav>
</header>
);

my $EN_STEPS = qq(<section class="section steps-sec" id="how">
  <div class="container">
    <h2 class="title center">How it <span class="hl">works</span></h2>
    <div class="steps">
      <div class="step"><span class="num">1</span><h3>You call or WhatsApp</h3><p>Tell us where you are, what the vehicle is doing and where it should go.</p></div>
      <div class="step"><span class="num">2</span><h3>You hear the price</h3><p>We agree the price before a truck sets off. No membership needed.</p></div>
      <div class="step"><span class="num">3</span><h3>We come to you</h3><p>Jump start or tyre change on the spot if possible — otherwise onto the flatbed.</p></div>
      <div class="step"><span class="num">4</span><h3>To your destination</h3><p>Garage, home, dealer or body shop: you choose.</p></div>
    </div>
  </div>
</section>
);

my $EN_CTA = qq(<section class="cta" id="contact">
  <div class="container cta-grid">
    <div>
      <h2>Need a tow?</h2>
      <p>Call or WhatsApp 24/7. Share your location and you hear the price before we leave.</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call $DISP</a>
        <a class="btn btn-navy" href="$WA?text=Hello%20Janssen%2C%20I%20need%20a%20tow.%20My%20location%3A%20">WhatsApp</a>
      </div>
    </div>
  </div>
</section>
);

my $EN_FOOT = qq(</main>
<footer>
  <div class="container foot-grid">
    <div>
      <a class="logo" href="/en/"><svg><use href="#i-logo"/></svg><span><b>janssen <em>towing</em></b><small>When you need us</small></span></a>
      <p>Towing, roadside assistance and car transport in Rotterdam, the Drechtsteden, Brabant and Zeeland. 24 hours a day, 7 days a week.</p>
      LANGSWITCH
    </div>
    <div><h4>Service area</h4><ul>$FOOT_WERK</ul></div>
    <div><h4>Services</h4><ul>$FOOT_SVC</ul></div>
    <div><h4>Contact</h4><ul>
      <li><a href="tel:$TEL">$DISP</a></li>
      <li><a href="$WA">WhatsApp</a></li>
      <li><a href="/en/privacy/">Privacy</a></li>
      <li><a href="/">Nederlands</a> · <a href="/en/">English</a></li>
    </ul></div>
  </div>
  <div class="container foot-bottom"><span>&copy; Janssen Towing</span></div>
</footer>
<script src="/assets/site.js" defer></script>
</body>
</html>
);

# Minimal lang CSS append once
{
  my $css = rd("$ROOT/assets/style.css");
  unless ($css =~ /\/\* lang-switch \*\//) {
    $css .= qq(\n/* lang-switch */\n.lang{display:inline-flex;align-items:center;gap:4px;font-size:13px;font-weight:600;margin-right:10px}\n.lang a{color:inherit;text-decoration:none;opacity:.85}\n.lang a:hover{opacity:1;text-decoration:underline}\n.navcta{display:flex;align-items:center;flex-wrap:wrap;gap:8px}\n);
    wr('assets/style.css', $css);
  }
}

sub faq_ld {
  my @f = @_;
  '{"@type": "FAQPage", "mainEntity": ['.join(', ', map {
    '{"@type": "Question", "name": '.js(plain($_->[0])).', "acceptedAnswer": {"@type": "Answer", "text": '.js(plain($_->[1])).'}}'
  } @f).']}';
}
sub faq_html {
  my @f = @_; my $i = 0; my $o = '';
  for (@f) { $o .= '<details'.($i++ ? '' : ' open').'><summary>'.typo($_->[0]).'</summary><p>'.typo($_->[1]).'</p></details>' }
  $o;
}
sub crumb_ld {
  my ($name, $path) = @_;
  '{"@type": "BreadcrumbList", "itemListElement": [{"@type": "ListItem", "position": 1, "name": "Home", "item": '.js("$SITE/en/")
  .'}, {"@type": "ListItem", "position": 2, "name": '.js($name).', "item": '.js($SITE.$path).'}]}';
}
sub split_faq { map { my ($q, $a) = split / :: /, $_, 2; defined $a or die "faq missing answer: $_\n"; [$q, $a] } @_ }

sub biz {
  my @area = @_;
  '{"@type": "AutomotiveBusiness", "@id": '.js("$SITE/#business").', "name": '.js($NAME_NL).', "alternateName": '.js($NAME).', "url": '.js("$SITE/")
  .', "telephone": '.js($TEL).', "email": "info@sleepdienstjanssen.nl", "openingHours": "Mo-Su 00:00-23:59", "areaServed": ['
  .join(', ', map { '{"@type": "City", "name": '.js($_).'}' } @area).']}';
}

my %CHIP = (map({ esc($PLACE{$_}{name}) => $_ } keys %PLACE),
  Botlek => 'botlek-maasvlakte', Maasvlakte => 'botlek-maasvlakte', Europoort => 'europoort',
  Pernis => 'pernis', Delfshaven => 'delfshaven',
  Charlois => 'rotterdam-zuid', Feijenoord => 'rotterdam-zuid', IJsselmonde => 'rotterdam-zuid');
sub link_chips {
  my ($html, $self) = @_;
  $html =~ s{<span>([^<]+)</span>}{
    my $n = $1; my $t = $CHIP{$n};
    ($t && $t ne $self) ? qq(<a href="/en/sleepdienst-$t/">$n</a>) : "<span>$n</span>"
  }ge;
  $html;
}

sub page_en {
  my (%a) = @_;
  my $nl_path = $a{nl_path};
  my $path = $a{path}; # /en/...
  my $h = $HEAD_TPL;
  $h =~ s{lang="nl-NL"}{lang="en"};
  my $t = esc($a{title}); my $d = esc($a{desc}); my $u = $SITE.$path;
  $h =~ s{<title>.*?</title>}{<title>$t</title>}s;
  $h =~ s{<meta name="description" content=".*?">}{<meta name="description" content="$d">};
  $h =~ s{<link rel="canonical" href=".*?">}{<link rel="canonical" href="$u">};
  $h =~ s{<meta property="og:title" content=".*?">}{<meta property="og:title" content="$t">};
  $h =~ s{<meta property="og:description" content=".*?">}{<meta property="og:description" content="$d">};
  $h =~ s{<meta property="og:url" content=".*?">}{<meta property="og:url" content="$u">};
  $h =~ s{<meta property="og:locale" content=".*?">}{<meta property="og:locale" content="en_GB">};
  # insert hreflang before </head>
  my $hl = hreflang_tags($nl_path);
  $h =~ s{</head>}{$hl</head>} or die 'hreflang insert';
  my $ld = $a{schema};
  $h =~ s{<script type="application/ld\+json">.*?</script>}{<script type="application/ld+json">$ld</script>}s or die 'ld';

  my $switch = lang_switcher($nl_path, 'en');
  my $header = $EN_HEADER; $header =~ s/LANGSWITCH/$switch/;
  my $foot = $EN_FOOT; $foot =~ s/LANGSWITCH/$switch/;
  my $crumb = esc($a{crumb});
  my $crumbs = qq(<nav class="crumbs container" aria-label="Breadcrumb"><a href="/en/">Home</a> › <span>$crumb</span></nav>\n);
  my $body_top = "$ICONS\n$EN_TOPBAR$header\n";
  return $h . $body_top . $crumbs . "<main>\n$a{body}\n$EN_CTA\n" . $foot;
}

my $DOES = sub {
  my $n = shift;
  qq(<h3>What we do in $n</h3>\n      <ul class="checks">\n)
  .qq(        <li><span><a href="/en/takelwagen/">Car towing</a> after a breakdown or accident</span></li>\n)
  .qq(        <li><span><a href="/en/pechhulp/">Roadside assistance</a> on the spot: <a href="/en/starthulp/">jump start</a>, flat battery, tyre change</span></li>\n)
  .qq(        <li><span><a href="/en/autotransport/">Car transport</a> to garage, home or scrapyard</span></li>\n)
  .qq(        <li><span><a href="/en/bergingsbedrijf/">Recovery</a> after an accident, also <a href="/en/vrachtwagen-pechhulp/">truck roadside assistance</a> and <a href="/en/vrachtwagen-berging/">truck recovery</a> via a partner</span></li>\n)
  .qq(        <li><span><a href="/en/elektrische-auto-slepen/">Electric car transport</a> on a flatbed</span></li>\n)
  .qq(        <li><span><a href="/en/autoambulance/">Flatbed recovery</a> for cars that may not or cannot drive, and <a href="/en/motor-vervoeren/">motorcycle transport</a></span></li>\n)
  .qq(        <li><span>Help with <a href="/en/verkeerd-getankt/">wrong fuel</a>, and <a href="/en/wat-kost-een-sleepdienst/">what a tow costs</a></span></li>\n      </ul>);
};

sub town_page_en {
  my $c = shift; my $s = $c->{slug}; my $raw = $c->{name}; my $n = esc($raw);
  my $roads = join '', map { '<li>'.typo($_).'</li>' } @{ $c->{road} // [] };
  my $areas = link_chips(join('', map { '<span>'.esc($_).'</span>' } split /, /, ($c->{area} // $raw)), $s);
  my $near  = join '', map { card($_) } grep { $PLACE{$_} } split /, /, ($c->{near} // '');
  my $local = join "\n      ", map { '<p>'.typo($_).'</p>' } @{ $c->{local} // [] };
  my @faqs = split_faq(@{ $c->{faq} // [] });
  push @faqs, ["How quickly can you be in $raw?", "We check which truck is closest. On the phone you get an arrival estimate for $raw, depending on your exact location and traffic."]
    unless grep { $_->[0] =~ /quickly|How fast/i } @faqs;
  push @faqs, ["What does a tow in $raw cost?", 'It depends on distance, vehicle and time of day. You hear the price on the phone and we agree it before anyone sets off.']
    unless grep { $_->[0] =~ /cost/i } @faqs;
  my $does = $DOES->($n);
  my $body = <<"H";
<section class="hero hero-city">
  <div class="container hero-grid">
    <div>
      <h1>Towing <span>$n</span></h1>
      <p>Broken down or in an accident in $n? $NAME helps you 24/7 with roadside assistance, towing and car transport in $n and the surrounding area. Call us and you hear straight away when we can be there and what it costs.</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call now: $DISP</a>
        <a class="btn btn-navy" href="#contact">Request help</a>
      </div>
      <div class="trust">
        <span><svg><use href="#i-clock"/></svg>24/7 in $n</span>
        <span><svg><use href="#i-euro"/></svg>Price agreed up front</span>
      </div>
    </div>
    <div class="hero-art">$ART</div>
  </div>
  $WAVE
</section>
<section class="section city-body">
  <div class="container city-grid">
    <article class="prose">
      <h2>Towing and recovery in $n</h2>
      <p>@{[ typo($c->{intro}) ]}</p>
      <h3>Roads in and around $n</h3>
      <ul class="roads">$roads</ul>
      <h3>Broken down in a difficult spot</h3>
      <p>@{[ typo($c->{spots}) ]}</p>
      <p>Exactly what to do when you break down is in our guide <a href="/en/pech-op-de-snelweg/">breakdown on the motorway</a>.</p>
      <h3>@{[ typo($c->{localh}) ]}</h3>
      $local
      <h3>Roadside assistance in $n</h3>
      <p>@{[ typo($c->{pech}) ]}</p>
      <h3>Car transport and recovery from $n</h3>
      <p>@{[ typo($c->{trans}) ]}</p>
      $does
    </article>
    <aside class="side">
      <div class="side-card">
        <h3>Help now in $n</h3>
        <p>Available 24 hours a day, 7 days a week.</p>
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>$DISP</a>
      </div>
      <div class="side-card">
        <h3>We also help in</h3>
        <div class="cities">$areas</div>
      </div>
    </aside>
  </div>
</section>
$EN_STEPS
<section class="section" id="faq">
  <div class="container">
    <h2 class="title center">Questions about towing in $n</h2>
    <div class="faq narrow">@{[ faq_html(@faqs) ]}</div>
  </div>
</section>
<section class="section area">
  <div class="container">
    <h2 class="title center">Also active <span class="hl">nearby</span></h2>
    <div class="cities-grid near">$near</div>
    <p style="margin-top:22px;text-align:center"><a href="/en/werkgebied/">View our full service area</a></p>
  </div>
</section>
H
  $body =~ s/\s+$//;
  my $nl_path = "/sleepdienst-$s/";
  my $path = "/en/sleepdienst-$s/";
  my $schema = '{"@context": "https://schema.org", "@graph": ['
    .biz($raw, split /, /, ($c->{area} // $raw)).', {"@type": "Service", "name": '.js("Towing $raw").', "serviceType": "Towing and roadside assistance", "provider": {"@id": '.js("$SITE/#business").'}, "areaServed": {"@type": "City", "name": '.js($raw).'}}, '
    .faq_ld(@faqs).', '.crumb_ld("Towing $raw", $path).']}';
  my $title = $c->{title} // "Towing $raw 24/7 | Janssen";
  my $desc  = $c->{desc} // "Towing $raw 24/7: roadside assistance and car towing. Price agreed up front, no membership. Call $DISP.";
  page_en(title => $title, desc => $desc, path => $path, nl_path => $nl_path, body => $body, schema => $schema, crumb => "Towing $raw");
}

sub service_page_en {
  my $v = shift; my $nl_path = "/$v->{slug}/"; my $path = "/en/$v->{slug}/";
  my $html = join "\n      ", map { typo($_) } @{ $v->{html} // [] };
  my $checks = join '', map { '<li>'.typo($_).'</li>' } @{ $v->{check} // [] };
  my @faqs = split_faq(@{ $v->{faq} // [] });
  my $near = join '', map { card($_) } grep { $PLACE{$_} } split /, /, ($v->{near} // '');
  my $others = join '', map { svc_card($_) } grep { $_->{slug} ne $v->{slug} } @SERVICES;
  my $body = <<"H";
<section class="hero hero-city">
  <div class="container hero-grid">
    <div>
      <h1>$v->{h1}</h1>
      <p>@{[ typo($v->{hero}) ]}</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call now: $DISP</a>
        <a class="btn btn-navy" href="#contact">Request help</a>
      </div>
      <div class="trust">
        <span><svg><use href="#i-clock"/></svg>Available 24/7</span>
        <span><svg><use href="#i-euro"/></svg>Price agreed up front</span>
      </div>
    </div>
    <div class="hero-art">$ART</div>
  </div>
  $WAVE
</section>
<section class="section city-body">
  <div class="container city-grid">
    <article class="prose">
      $html
    </article>
    <aside class="side">
      <div class="side-card">
        <h3>@{[ typo($v->{side}) ]}</h3>
        <p>Available 24 hours a day, 7 days a week.</p>
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>$DISP</a>
      </div>
      <div class="side-card">
        <h3>In short</h3>
        <ul class="checks">$checks</ul>
      </div>
    </aside>
  </div>
</section>
$EN_STEPS
<section class="section" id="faq">
  <div class="container">
    <h2 class="title center">@{[ typo($v->{faqh}) ]}</h2>
    <div class="faq narrow">@{[ faq_html(@faqs) ]}</div>
  </div>
</section>
<section class="section area">
  <div class="container">
    <h2 class="title center">Where we <span class="hl">operate</span></h2>
    <div class="cities-grid near">$near</div>
    <p style="margin-top:22px;text-align:center"><a href="/en/werkgebied/">View our full service area</a></p>
    <h2 class="title center" style="margin-top:44px">More <span class="hl">services</span></h2>
    <div class="cities-grid near">$others</div>
  </div>
</section>
H
  $body =~ s/\s+$//;
  my $schema = '{"@context": "https://schema.org", "@graph": ['
    .biz(map { $PLACE{$_}{name} } grep { $PLACE{$_} } @FOOT_TOWNS).', {"@type": "Service", "name": '.js($v->{crumb}).', "serviceType": '.js($v->{crumb}).', "provider": {"@id": '.js("$SITE/#business").'}}, '
    .faq_ld(@faqs).', '.crumb_ld($v->{crumb}, $path).']}';
  page_en(title => $v->{title}, desc => $v->{desc}, path => $path, nl_path => $nl_path, body => $body, schema => $schema, crumb => $v->{crumb});
}

# Werkgebied EN
my @REGIONS = (
  ['Rijnmond', 'Rotterdam and Rijnmond', 'From Rotterdam’s ring to the ports, Voorne aan Zee and the Hoeksche Waard. Many tunnels and bridges, heavy freight and a port that never sleeps.'],
  ['Drechtsteden', 'Drechtsteden and Alblasserwaard', 'The river region between Rotterdam and Brabant, with the A15 and A16 as the busiest routes.'],
  ['Brabant', 'North Brabant', 'From Bergen op Zoom and Roosendaal to Eindhoven, Helmond and Oss — along the A16, A58, A2 and A59.'],
  ['Zeeland', 'Zeeland', 'Walcheren, Zuid-Beveland, Schouwen-Duiveland and Zeeuws-Vlaanderen. Longer distances and, in summer, many tourists with caravans or campers.'],
  ['Rivierenland', 'Rivierenland', 'The Betuwe and Bommelerwaard, along the A15 and A2 on both sides of the Waal.'],
);
sub werkgebied_en {
  my $secs = '';
  for my $r (@REGIONS) {
    my ($k, $h, $p) = @$r;
    my @s = sort { $PLACE{$a}{name} cmp $PLACE{$b}{name} } grep { ($PLACE{$_}{region} // '') eq $k } keys %PLACE;
    next unless @s;
    $secs .= qq(<h2 class="title">$h</h2>\n    <p>$p</p>\n    <div class="cities-grid near" style="margin:18px 0 40px">).join('', map { card($_) } @s)."</div>\n    ";
  }
  my $body = <<"H";
<section class="hero hero-city">
  <div class="container hero-grid">
    <div>
      <h1>Our <span>service area</span></h1>
      <p>$NAME helps 24/7 across south-west Netherlands and the river region. Is your town missing? Call anyway — often we can still help, and you hear immediately whether that works and what it costs.</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call now: $DISP</a>
      </div>
    </div>
    <div class="hero-art">$ART</div>
  </div>
  $WAVE
</section>
<section class="section area"><div class="container">$secs</div></section>
H
  my $path = '/en/werkgebied/';
  my $schema = '{"@context": "https://schema.org", "@graph": ['.biz(sort map { $_->{name} } values %PLACE).', '.crumb_ld('Service area', $path).']}';
  page_en(title => "Towing service area: all locations | $NAME",
    desc => "All places where $NAME helps 24/7: Rotterdam, Drechtsteden, Brabant, Zeeland and Rivierenland. Call $DISP.",
    path => $path, nl_path => '/werkgebied/', body => $body, schema => $schema, crumb => 'Service area');
}

sub home_en {
  my @home = qw(rotterdam eindhoven barendrecht breda dordrecht tilburg den-bosch schiedam rotterdam-zuid gorinchem spijkenisse goes);
  my $grid = join '', map { card($_) } grep { $PLACE{$_} } @home;
  my $svc = join '', map { svc_card($_) } @SERVICES;
  my $haven = join '', map { card($_) } grep { $PLACE{$_} } qw(botlek-maasvlakte europoort pernis delfshaven);
  my $body = <<"H";
<section class="hero hero-city">
  <div class="container hero-grid">
    <div>
      <h1>Towing &amp; roadside assistance <span>24/7</span></h1>
      <p>Broken down in Rotterdam, the port, Brabant or Zeeland? $NAME tows cars and vans on a flatbed, helps on the spot when we can, and agrees the price before we leave. No membership. Tourists and expats: we work in English.</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call $DISP</a>
        <a class="btn btn-navy" href="$WA?text=Hello%20Janssen%2C%20I%20need%20a%20tow.%20My%20location%3A%20">WhatsApp</a>
      </div>
      <div class="trust">
        <span><svg><use href="#i-clock"/></svg>24/7 including nights</span>
        <span><svg><use href="#i-euro"/></svg>Price agreed up front</span>
        <span><svg><use href="#i-bolt"/></svg>English spoken</span>
      </div>
    </div>
    <div class="hero-art">$ART</div>
  </div>
  $WAVE
</section>
<section class="section area" id="services">
  <div class="container">
    <h2 class="title center">Our <span class="hl">services</span></h2>
    <div class="cities-grid near">$svc</div>
  </div>
</section>
$EN_STEPS
<section class="section area" id="faq">
  <div class="container">
    <h2 class="title center">Where we <span class="hl">help</span></h2>
    <div class="cities-grid">$grid</div>
    <h3 class="title center" style="margin-top:36px">Port &amp; harbour</h3>
    <div class="cities-grid near">$haven</div>
    <p style="margin-top:22px;text-align:center"><a class="btn btn-navy" href="/en/werkgebied/">All locations</a></p>
  </div>
</section>
<section class="section" id="faq2">
  <div class="container">
    <h2 class="title center">Frequently asked <span class="hl">questions</span></h2>
    <div class="faq narrow">
      <details open><summary>Do I need an ANWB membership?</summary><p>No. You call us per job and hear the price before we set off.</p></details>
      <details><summary>Do you speak English?</summary><p>Yes. Especially useful in Amsterdam and Rotterdam city centre for tourists and expats. Call or WhatsApp in English.</p></details>
      <details><summary>Can you help with a truck in the port?</summary><p>Yes, via partners with heavy equipment. See <a href="/en/vrachtwagen-pechhulp/">truck roadside assistance</a> and our Botlek, Europoort and Pernis pages.</p></details>
      <details><summary>What does a tow cost?</summary><p>It depends on distance, vehicle and time. You always hear the price up front. More on <a href="/en/wat-kost-een-sleepdienst/">what a tow costs</a>.</p></details>
    </div>
  </div>
</section>
H
  my $path = '/en/';
  my $schema = '{"@context": "https://schema.org", "@graph": ['.biz(qw(Rotterdam Dordrecht Breda Tilburg Eindhoven)).', '.crumb_ld('Home', $path).']}';
  # home has no mid crumb really — still ok
  page_en(title => "Towing & roadside assistance 24/7 | Janssen Towing",
    desc => "Towing and roadside assistance in Rotterdam, the port, Brabant and Zeeland. 24/7, price agreed up front, English spoken. Call $DISP.",
    path => $path, nl_path => '/', body => $body, schema => $schema, crumb => 'Home');
}

sub simple_guide_en {
  my (%a) = @_;
  my $body = $a{body};
  my $path = $a{path};
  my $nl_path = $a{nl_path};
  my $schema = '{"@context": "https://schema.org", "@graph": ['.biz(qw(Rotterdam)).', '.crumb_ld($a{crumb}, $path).']}';
  page_en(title => $a{title}, desc => $a{desc}, path => $path, nl_path => $nl_path, body => $body, schema => $schema, crumb => $a{crumb});
}

# Motorway guide EN
my $PECH_BODY = <<"H";
<section class="hero hero-city"><div class="container hero-grid"><div>
<h1>Breakdown on the <span>motorway</span></h1>
<p>Hazard lights on, behind the guardrail, then call us. On a live lane call 112 first. We tow 24/7 with the price agreed up front.</p>
<div class="actions"><a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call $DISP</a></div>
</div><div class="hero-art">$ART</div></div>$WAVE</section>
<section class="section city-body"><div class="container"><article class="prose">
<h2>Stay safe first</h2>
<ol class="checks"><li><span>Switch on hazard lights.</span></li><li><span>If you can, leave the car on the hard shoulder and stand <b>behind the guardrail</b>.</span></li><li><span>On a live lane or in a tunnel: call <b>112</b> (or follow tunnel instructions).</span></li><li><span>Note the road number, direction and kilometre marker.</span></li><li><span>Then call $DISP or WhatsApp your live location.</span></li></ol>
<h2>What we do</h2>
<p>Jump start or tyre change when safe. Otherwise the car goes on a flatbed to the garage you choose. No membership required.</p>
<p>Also useful: <a href="/en/pechhulp/">roadside assistance</a>, <a href="/en/wat-kost-een-sleepdienst/">what a tow costs</a>, <a href="/en/elektrische-auto-slepen/">towing an electric car</a>.</p>
</article></div></section>
$EN_STEPS
H

my $EV_BODY = <<"H";
<section class="hero hero-city"><div class="container hero-grid"><div>
<h1>Towing an <span>electric car</span></h1>
<p>An EV must not be towed with drive wheels on the road. We always transport electric cars on a flatbed. Price agreed up front, 24/7.</p>
<div class="actions"><a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Call $DISP</a></div>
</div><div class="hero-art">$ART</div></div>$WAVE</section>
<section class="section city-body"><div class="container"><article class="prose">
<h2>Why a flatbed?</h2>
<p>Towing an EV on a cable can damage the electric motor. All wheels must be off the ground. Hybrids often need the same treatment — tell us the model when you call.</p>
<h2>Empty high-voltage battery</h2>
<p>If the car will not move because the main battery is empty, we take it to a charge point or dealer you choose. The 12&nbsp;V battery can sometimes be jump-started — see <a href="/en/starthulp/">jump start</a>.</p>
<p>More: <a href="/en/autoambulance/">flatbed recovery</a>, <a href="/en/pechhulp/">roadside assistance</a>.</p>
</article></div></section>
$EN_STEPS
H

my $PRIV_BODY = <<"H";
<section class="hero hero-city"><div class="container hero-grid"><div>
<h1>Privacy</h1>
<p>How $NAME_NL (Janssen Towing) handles your personal data when you call, WhatsApp or use this website.</p>
</div></div>$WAVE</section>
<section class="section"><div class="container narrow prose">
<p>We use your phone number, location and vehicle details only to provide towing or roadside assistance and to communicate about the job. We do not sell your data. For questions: <a href="mailto:info\@sleepdienstjanssen.nl">info\@sleepdienstjanssen.nl</a> or $DISP.</p>
<p><a href="/privacy/">Nederlandse versie / Dutch version</a></p>
</div></section>
H

# ===== Write EN pages =====
my $n = 0;
wr('en/index.html', home_en()); $n++;
wr('en/werkgebied/index.html', werkgebied_en()); $n++;
for my $c (@TOWNS) {
  wr("en/sleepdienst-$c->{slug}/index.html", town_page_en($c)); $n++;
}
for my $v (@SERVICES) {
  wr("en/$v->{slug}/index.html", service_page_en($v)); $n++;
}
wr('en/pech-op-de-snelweg/index.html', simple_guide_en(
  title => 'Breakdown on the motorway | Janssen Towing',
  desc => "Broken down on the motorway? Stay safe, then call Janssen 24/7. Price agreed up front. Call $DISP.",
  path => '/en/pech-op-de-snelweg/', nl_path => '/pech-op-de-snelweg/', crumb => 'Breakdown on the motorway', body => $PECH_BODY)); $n++;
wr('en/elektrische-auto-slepen/index.html', simple_guide_en(
  title => 'Towing an electric car on a flatbed | Janssen',
  desc => "EV towing on a flatbed only. 24/7, price agreed up front. Call $DISP.",
  path => '/en/elektrische-auto-slepen/', nl_path => '/elektrische-auto-slepen/', crumb => 'Towing an electric car', body => $EV_BODY)); $n++;
wr('en/privacy/index.html', simple_guide_en(
  title => 'Privacy | Janssen Towing',
  desc => 'Privacy information for Janssen Towing / Sleepdienst Janssen.',
  path => '/en/privacy/', nl_path => '/privacy/', crumb => 'Privacy', body => $PRIV_BODY)); $n++;

print "EN pages written: $n\n";

# ===== Patch NL pages: hreflang + lang switcher =====
sub patch_nl_file {
  my ($rel, $nl_path) = @_;
  my $f = "$ROOT/$rel";
  return unless -f $f;
  my $h = rd($f);
  # hreflang
  unless ($h =~ /hreflang="en"/) {
    my $hl = hreflang_tags($nl_path);
    $h =~ s{</head>}{$hl</head>} or warn "no head $rel";
  }
  # lang switcher in navcta
  my $sw = lang_switcher($nl_path, 'nl');
  if ($h =~ /class="navcta"/ && $h !~ /class="lang"/) {
    $h =~ s{(<div class="navcta">)}{$1\n      $sw} or warn "navcta $rel";
  }
  # footer language line
  unless ($h =~ /hreflang="en">EN</ || $h =~ />English</) {
    $h =~ s{(<div class="foot-bottom">)}{<div class="container" style="padding-bottom:8px;font-size:13px"><a href="$nl_path">NL</a> · <a href="@{[en_path($nl_path)]}" hreflang="en">EN</a></div>\n$1}
      or $h =~ s{(</footer>)}{<div class="container" style="padding:8px 0;font-size:13px"><a href="$nl_path">NL</a> · <a href="@{[en_path($nl_path)]}" hreflang="en">EN</a></div>\n$1};
  }
  wr($rel, $h);
}

# Map of NL files
patch_nl_file('index.html', '/');
patch_nl_file('werkgebied/index.html', '/werkgebied/');
patch_nl_file('privacy/index.html', '/privacy/');
patch_nl_file('pech-op-de-snelweg/index.html', '/pech-op-de-snelweg/');
patch_nl_file('elektrische-auto-slepen/index.html', '/elektrische-auto-slepen/');
for my $c (@TOWNS) {
  patch_nl_file("sleepdienst-$c->{slug}/index.html", "/sleepdienst-$c->{slug}/");
}
for my $v (@SERVICES) {
  patch_nl_file("$v->{slug}/index.html", "/$v->{slug}/");
}
# Also pechhulp etc already in SERVICES; diensten hub if any
patch_nl_file('diensten/index.html', '/diensten/') if -f "$ROOT/diensten/index.html";

print "NL hreflang/switcher patched\n";

# ===== Sitemap: NL + EN =====
my @urls = ('/', '/en/', '/werkgebied/', '/en/werkgebied/');
push @urls, map { ("/$_->{slug}/", "/en/$_->{slug}/") } @SERVICES;
push @urls, map { ("/sleepdienst-$_->{slug}/", "/en/sleepdienst-$_->{slug}/") } @TOWNS;
push @urls, '/pech-op-de-snelweg/', '/en/pech-op-de-snelweg/', '/elektrische-auto-slepen/', '/en/elektrische-auto-slepen/', '/privacy/', '/en/privacy/';
# unique preserve order
my %seen; @urls = grep { !$seen{$_}++ } @urls;
wr('sitemap.xml', qq(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
  .join('', map { qq(  <url><loc>$SITE$_</loc><lastmod>$TODAY</lastmod></url>\n) } @urls)
  .qq(</urlset>\n));
print "Sitemap URLs: ".scalar(@urls)."\n";

# robots already points to sitemap — ok
# SEO notes
my $notes = -f "$ROOT/_build/SEO-NOTES.md" ? rd("$ROOT/_build/SEO-NOTES.md") : '';
unless ($notes =~ /English \/en\//) {
  $notes .= qq(\n## $TODAY – English site /en/\n- Full English mirror under `/en/` (home, services, all towns/hubs, motorway + EV guides, privacy, werkgebied).\n- hreflang nl-NL ↔ en + x-default; NL|EN switcher in header/footer.\n- Content: `src/pages-en/`; build: `perl build-en.pl` (after `perl build.pl`).\n- Phone/WhatsApp unchanged: $DISP.\n);
  wr('_build/SEO-NOTES.md', $notes);
}
print "Done.\n";
