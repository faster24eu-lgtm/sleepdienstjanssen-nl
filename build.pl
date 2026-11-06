#!/usr/bin/perl
# Bouwt de uitbreiding van Sleepdienst Janssen: stadspagina's, dienstpagina's en /werkgebied/.
# Daarna: Engelse /en/ mirror via build-en.pl (hreflang + sitemap NL+EN).
#
#   perl build.pl
#
# Inhoud staat in src/pages/*.txt. Het raamwerk (head, header, footer, kaart, stappen) komt uit de
# bestaande pagina sleepdienst-dordrecht/index.html, dus de vormgeving blijft overal gelijk.
# De acht oude stadspagina's, de home en de gidsen krijgen hier hun extra secties, links en footer.
# build.py kent deze pagina's niet: draai die niet meer, anders verdwijnen footer en links.
use strict; use warnings; use utf8; use Encode;
use FindBin qw($Bin);
binmode STDOUT, ':utf8';

my $ROOT  = $Bin;
my $SITE  = 'https://sleepdienstjanssen.nl';
my $NAME  = 'Sleepdienst Janssen';
my $DISP  = '0970 1022 9095';
my $TEL   = '+3197010229095';
my @t = localtime; my $TODAY = sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3];

sub rd { my $f = shift; open my $h, '<:raw', $f or die "$f: $!"; local $/; my $s = decode('UTF-8', scalar <$h>); $s =~ s/\r\n/\n/g; $s }
sub wr {
  my ($rel, $s) = @_; my $f = "$ROOT/$rel";
  (my $d = $f) =~ s{/[^/]*$}{}; my $p = '';
  for (split m{/}, $d) { $p .= "$_/"; mkdir $p unless -d $p }
  $s =~ s/\n/\r\n/g unless $rel =~ /\.xml$/;
  open my $h, '>:raw', $f or die "$f: $!"; print $h encode('UTF-8', $s); close $h;
}
sub esc { my $s = shift; $s =~ s/&(?!#?\w+;)/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; $s =~ s/'/&#x27;/g; $s }
sub typo { my $s = shift; $s =~ s/'/&rsquo;/g; $s }
sub plain { my $s = shift; $s =~ s/<[^>]+>//g; $s =~ s/&rsquo;/'/g; $s =~ s/&amp;/&/g; $s =~ s/\s+/ /g; $s }
sub js { my $s = shift; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; qq("$s") }

# ===== Inhoud inlezen =====
sub parse {
  my $file = shift; my @out; my $cur;
  for my $l (split /\n/, rd("$ROOT/src/pages/$file")) {
    next if $l =~ /^\s*(#.*)?$/;
    if ($l =~ /^@\@(\w+) (\S+)$/) { $cur = { kind => $1, slug => $2 }; push @out, $cur; next }
    $l =~ /^(\w+): (.*)$/ or die "$file: kan regel niet lezen: $l\n";
    my ($k, $v) = ($1, $2);
    if ($k =~ /^(road|local|faq|html|check)$/) { push @{ $cur->{$k} }, $v } else { $cur->{$k} = $v }
  }
  @out;
}
my @TOWNS; push @TOWNS, parse($_) for qw(towns-rijnmond.txt towns-drecht.txt towns-brabant.txt towns-zeeland.txt);
my @EXTRA    = parse('bestaand.txt');
my @SERVICES = parse('diensten.txt');

my %OLD = (
  rotterdam  => ['Rotterdam', 'Zuid-Holland', 'Rijnmond'],
  spijkenisse=> ['Spijkenisse', 'Zuid-Holland', 'Rijnmond'],
  dordrecht  => ['Dordrecht', 'Zuid-Holland', 'Drechtsteden'],
  gorinchem  => ['Gorinchem', 'Zuid-Holland', 'Drechtsteden'],
  breda      => ['Breda', 'Noord-Brabant', 'Brabant'],
  tilburg    => ['Tilburg', 'Noord-Brabant', 'Brabant'],
  'den-bosch'=> ["'s-Hertogenbosch", 'Noord-Brabant', 'Brabant'],
  goes       => ['Goes', 'Zeeland', 'Zeeland'],
);
my %PLACE = map { $_ => { name => $OLD{$_}[0], prov => $OLD{$_}[1], region => $OLD{$_}[2] } } keys %OLD;
$PLACE{$_->{slug}} = $_ for @TOWNS;

sub card {
  my $s = shift; my $c = $PLACE{$s} or die "onbekende plaats: $s\n";
  my $n = esc($c->{name});
  qq(<a class="city" href="/sleepdienst-$s/"><svg><use href="#i-pin"/></svg><span><b>Sleepdienst $n</b><small>).esc($c->{prov}).qq(</small></span></a>);
}
sub svc_card { my $s = shift; qq(<a class="city" href="/$s->{slug}/"><svg><use href="#i-truck"/></svg><span><b>).esc($s->{crumb}).qq(</b><small>).esc($s->{cardsub}).qq(</small></span></a>) }

# ===== Footer =====
my @FOOT_TOWNS = qw(rotterdam eindhoven barendrecht breda dordrecht tilburg den-bosch schiedam rotterdam-zuid gorinchem);
my $FOOT_WERK = join '', map { qq(<li><a href="/sleepdienst-$_/">Sleepdienst ).esc($PLACE{$_}{name}).qq(</a></li>) } @FOOT_TOWNS;
$FOOT_WERK .= '<li><a href="/werkgebied/"><b>Alle plaatsen</b></a></li>';
my $FOOT_SVC = join '', map { qq(<li><a href="/$_->{slug}/">).esc($_->{crumb}).'</a></li>' } @SERVICES;
$FOOT_SVC .= '<li><a href="/pech-op-de-snelweg/">Pech op de snelweg</a></li><li><a href="/elektrische-auto-slepen/">Elektrische auto slepen</a></li>';

sub patch_footer {
  my $h = shift;
  $h =~ s{<div><h4>Werkgebied</h4><ul>.*?</ul></div>}{<div><h4>Werkgebied</h4><ul>$FOOT_WERK</ul></div>}s or die 'footer werkgebied';
  $h =~ s{<div><h4>Diensten</h4><ul>.*?</ul></div>}{<div><h4>Diensten</h4><ul>$FOOT_SVC</ul></div>}s or die 'footer diensten';
  $h;
}

# ===== Raamwerk uit een bestaande pagina =====
my $TPL = rd("$ROOT/sleepdienst-dordrecht/index.html");
my ($HEAD_TPL, $BODY_TOP) = $TPL =~ m{^(.*?</head>\n)(.*?)<nav class="crumbs}s or die 'shell top';
# Never copy Dordrecht hreflang / lang switcher into other NL pages
$HEAD_TPL =~ s{<link rel="alternate" hreflang="[^"]+" href="[^"]+">\s*}{}g;
$BODY_TOP =~ s{<div class="lang"[^>]*>.*?</div>\s*}{}g;
$TPL =~ s{<div class="container" style="padding-bottom:8px;font-size:13px"><a href="/sleepdienst-dordrecht/">NL</a> · <a href="/en/sleepdienst-dordrecht/" hreflang="en">EN</a></div>\s*}{}g;
my ($FOOT_HTML) = $TPL =~ m{(</main>.*)$}s or die 'shell foot';
my ($CTA)   = $TPL =~ m{(<section class="cta" id="contact">.*?</section>)}s or die 'cta';
my ($STEPS) = $TPL =~ m{(<section class="section steps-sec" id="werkwijze">.*?</section>)}s or die 'steps';
my ($MAP)   = $TPL =~ m{<div class="map small">(<svg.*?</svg>)</div>}s or die 'map';
my $WAVE = '<svg class="wave" viewBox="0 0 1440 120" preserveAspectRatio="none" aria-hidden="true"><path d="M0 70 C 240 130, 480 10, 760 50 S 1220 120, 1440 30 L1440 120 L0 120Z" fill="#fff"/></svg>';
my $ART = rd("$ROOT/src/art-truck.svg"); $ART =~ s/\s+$//;
my $BIZ = sub {
  my @area = @_;
  '{"@type": "AutomotiveBusiness", "@id": '.js("$SITE/#business").', "name": '.js($NAME).', "url": '.js("$SITE/")
  .', "telephone": '.js($TEL).', "email": "info@sleepdienstjanssen.nl", "openingHours": "Mo-Su 00:00-23:59", "areaServed": ['
  .join(', ', map { '{"@type": "City", "name": '.js($_).'}' } @area).']}';
};
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
  '{"@type": "BreadcrumbList", "itemListElement": [{"@type": "ListItem", "position": 1, "name": "Home", "item": '.js("$SITE/")
  .'}, {"@type": "ListItem", "position": 2, "name": '.js($name).', "item": '.js($SITE.$path).'}]}';
}
sub split_faq { map { my ($q, $a) = split / :: /, $_, 2; defined $a or die "faq zonder antwoord: $_\n"; [$q, $a] } @_ }

sub page {
  my (%a) = @_;
  my $h = $HEAD_TPL; my $t = esc($a{title}); my $d = esc($a{desc}); my $u = $SITE.$a{path};
  $h =~ s{<title>.*?</title>}{<title>$t</title>}s;
  $h =~ s{<meta name="description" content=".*?">}{<meta name="description" content="$d">};
  $h =~ s{<link rel="canonical" href=".*?">}{<link rel="canonical" href="$u">};
  $h =~ s{<meta property="og:title" content=".*?">}{<meta property="og:title" content="$t">};
  $h =~ s{<meta property="og:description" content=".*?">}{<meta property="og:description" content="$d">};
  $h =~ s{<meta property="og:url" content=".*?">}{<meta property="og:url" content="$u">};
  my $ld = $a{schema};
  $h =~ s{<script type="application/ld\+json">.*?</script>}{<script type="application/ld+json">$ld</script>}s or die 'ld';
  my $crumb = esc($a{crumb});
  my $c = qq(<nav class="crumbs container" aria-label="Kruimelpad"><a href="/">Home</a> › <span>$crumb</span></nav>\n);
  $h . $BODY_TOP . $c . "<main>\n$a{body}\n$CTA\n" . patch_footer($FOOT_HTML);
}

sub map_for {
  my ($slug, $lon, $lat) = @_;
  my $m = $MAP;
  $m =~ s/class="pin on"/class="pin"/g; $m =~ s/r="6"\/>/r="4.5"\/>/g;
  my $x = int(66 + ($lon - 4.48) * 61 + .5);
  my $y = int(132 + (51.92 - $lat) * 115 + .5);
  $y = 186 if $y > 186; $x = 22 if $x < 22;
  my $n = esc($PLACE{$slug}{name});
  $m =~ s{</g>\s*</svg>$}{<a href="/sleepdienst-$slug/" class="pin on"><circle cx="$x" cy="$y" r="6"/><title>Sleepdienst $n</title></a></g>\n</svg>}s or die 'map pin';
  $m;
}

# Plaatsnamen in "Wij helpen ook in" worden een link als die plaats een eigen pagina heeft.
my %CHIP = (map({ esc($PLACE{$_}{name}) => $_ } keys %PLACE),
  Botlek => 'botlek-maasvlakte', Maasvlakte => 'botlek-maasvlakte', Europoort => 'europoort',
  Pernis => 'pernis', Delfshaven => 'delfshaven',
  Charlois => 'rotterdam-zuid', Feijenoord => 'rotterdam-zuid', IJsselmonde => 'rotterdam-zuid');
sub link_chips {
  my ($html, $self) = @_;
  $html =~ s{<span>([^<]+)</span>}{ my $n = $1; my $t = $CHIP{$n};
    ($t && $t ne $self) ? qq(<a href="/sleepdienst-$t/">$n</a>) : "<span>$n</span>" }ge;
  $html;
}

my $DOES = sub {
  my $n = shift;
  qq(<h3>Wat wij doen in $n</h3>\n      <ul class="checks">\n)
  .qq(        <li><span><a href="/takelwagen/">Auto slepen</a> na pech of een ongeval</span></li>\n)
  .qq(        <li><span><a href="/pechhulp/">Pechhulp</a> ter plaatse: <a href="/starthulp/">starthulp</a>, lege accu, band wisselen</span></li>\n)
  .qq(        <li><span><a href="/autotransport/">Autotransport</a> naar garage, huis of demontagebedrijf</span></li>\n)
  .qq(        <li><span><a href="/bergingsbedrijf/">Berging</a> na een ongeval, ook <a href="/vrachtwagen-pechhulp/">vrachtwagen pechhulp</a> en <a href="/vrachtwagen-berging/">berging</a> via een partner</span></li>\n)
  .qq(        <li><span><a href="/elektrische-auto-slepen/">Transport van elektrische auto&#x27;s</a> op een plateauwagen</span></li>\n)
  .qq(        <li><span><a href="/autoambulance/">Autoambulance</a> voor auto&#x27;s die niet meer mogen of kunnen rijden, en <a href="/motor-vervoeren/">motoren vervoeren</a></span></li>\n)
  .qq(        <li><span>Hulp bij <a href="/verkeerd-getankt/">verkeerd getankt</a>, en uitleg over <a href="/wat-kost-een-sleepdienst/">wat een sleepdienst kost</a></span></li>\n      </ul>);
};

# ===== Stadspagina =====
sub town_page {
  my $c = shift; my $s = $c->{slug}; my $raw = $c->{name}; my $n = esc($raw);
  my ($lon, $lat) = split ' ', $c->{geo};
  my $roads = join '', map { '<li>'.typo($_).'</li>' } @{ $c->{road} };
  my $areas = link_chips(join('', map { '<span>'.esc($_).'</span>' } split /, /, $c->{area}), $s);
  my $near  = join '', map { card($_) } split /, /, $c->{near};
  my $local = join "\n      ", map { '<p>'.typo($_).'</p>' } @{ $c->{local} };
  my @faqs = (split_faq(@{ $c->{faq} }),
    ["Hoe snel zijn jullie in $raw?", "Bij uw melding kijken we welke wagen het dichtst bij staat. U krijgt aan de telefoon een inschatting van de aankomsttijd in $raw, afhankelijk van uw exacte locatie en de verkeersdrukte."],
    ["Wat kost een sleepdienst in $raw?", 'Dat hangt af van de afstand, het voertuig en het tijdstip. U hoort de prijs aan de telefoon en we spreken die af voordat er iemand vertrekt.']);
  my $does = $DOES->($n);
  my $body = <<"H";
<section class="hero hero-city">
  <div class="container hero-grid">
    <div>
      <h1>Sleepdienst <span>$n</span></h1>
      <p>Pech of een ongeval in $n? $NAME helpt u 24/7 met pechhulp, slepen en autotransport in $n en omgeving. Bel ons en u hoort direct wanneer we er zijn en wat het kost.</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Bel direct: $DISP</a>
        <a class="btn btn-navy" href="#contact">Hulp aanvragen</a>
      </div>
      <div class="trust">
        <span><svg><use href="#i-clock"/></svg>24/7 in $n</span>
        <span><svg><use href="#i-euro"/></svg>Prijs vooraf afgesproken</span>
      </div>
    </div>
    <div class="hero-art">$ART</div>
  </div>
  $WAVE
</section>
<section class="section city-body">
  <div class="container city-grid">
    <article class="prose">
      <h2>Sleepdienst en takeldienst in $n</h2>
      <p>@{[ typo($c->{intro}) ]}</p>
      <h3>Wegen in en rond $n</h3>
      <ul class="roads">$roads</ul>
      <h3>Pech op een lastige plek</h3>
      <p>@{[ typo($c->{spots}) ]}</p>
      <p>Wat u precies moet doen als u stilvalt, leest u in onze gids <a href="/pech-op-de-snelweg/">pech op de snelweg</a>.</p>
      <h3>@{[ typo($c->{localh}) ]}</h3>
      $local
      <h3>Pechhulp in $n</h3>
      <p>@{[ typo($c->{pech}) ]}</p>
      <h3>Autotransport en berging vanuit $n</h3>
      <p>@{[ typo($c->{trans}) ]}</p>
      $does
    </article>
    <aside class="side">
      <div class="side-card">
        <h3>Direct hulp in $n</h3>
        <p>24 uur per dag, 7 dagen per week bereikbaar.</p>
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>$DISP</a>
      </div>
      <div class="side-card">
        <h3>Wij helpen ook in</h3>
        <div class="cities">$areas</div>
      </div>
      <div class="map small">@{[ map_for($s, $lon, $lat) ]}</div>
    </aside>
  </div>
</section>
$STEPS
<section class="section" id="faq">
  <div class="container">
    <h2 class="title center">Vragen over onze sleepdienst in $n</h2>
    <div class="faq narrow">@{[ faq_html(@faqs) ]}</div>
  </div>
</section>
<section class="section area">
  <div class="container">
    <h2 class="title center">Ook actief in de <span class="hl">buurt</span></h2>
    <div class="cities-grid near">$near</div>
    <p style="margin-top:22px;text-align:center"><a href="/werkgebied/">Bekijk ons hele werkgebied</a></p>
  </div>
</section>
H
  $body =~ s/\s+$//;
  my $path = "/sleepdienst-$s/";
  my $schema = '{"@context": "https://schema.org", "@graph": ['
    .$BIZ->($raw, split /, /, $c->{area}).', {"@type": "Service", "name": '.js("Sleepdienst $raw").', "serviceType": "Sleepdienst en pechhulp", "provider": {"@id": '.js("$SITE/#business").'}, "areaServed": {"@type": "City", "name": '.js($raw).'}}, '
    .faq_ld(@faqs).', '.crumb_ld("Sleepdienst $raw", $path).']}';
  my $title = $c->{title} // "Sleepdienst $raw 24/7 | prijs vooraf | Janssen";
  $title = "Sleepdienst $raw 24/7 | Janssen" if !defined $c->{title} && length($title) > 60;
  my $desc  = $c->{desc} // "Sleepdienst $raw 24/7: pechhulp en auto slepen. Vaste prijs vooraf, geen abonnement. Bel $DISP.";
  page(title => $title, desc => $desc, path => $path, body => $body, schema => $schema, crumb => "Sleepdienst $raw");
}

# ===== Dienstpagina =====
sub service_page {
  my $v = shift; my $path = "/$v->{slug}/";
  my $html = join "\n      ", map { typo($_) } @{ $v->{html} };
  $html =~ s/(<a href=)&rsquo;/$1'/g;
  my $checks = join '', map { '<li>'.typo($_).'</li>' } @{ $v->{check} };
  my @faqs = split_faq(@{ $v->{faq} });
  my $near = join '', map { card($_) } split /, /, $v->{near};
  my $others = join '', map { svc_card($_) } grep { $_->{slug} ne $v->{slug} } @SERVICES;
  my $body = <<"H";
<section class="hero hero-city">
  <div class="container hero-grid">
    <div>
      <h1>$v->{h1}</h1>
      <p>@{[ typo($v->{hero}) ]}</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Bel direct: $DISP</a>
        <a class="btn btn-navy" href="#contact">Hulp aanvragen</a>
      </div>
      <div class="trust">
        <span><svg><use href="#i-clock"/></svg>24/7 bereikbaar</span>
        <span><svg><use href="#i-euro"/></svg>Prijs vooraf afgesproken</span>
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
        <p>24 uur per dag, 7 dagen per week bereikbaar.</p>
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>$DISP</a>
      </div>
      <div class="side-card">
        <h3>In het kort</h3>
        <ul class="checks">$checks</ul>
      </div>
    </aside>
  </div>
</section>
$STEPS
<section class="section" id="faq">
  <div class="container">
    <h2 class="title center">@{[ typo($v->{faqh}) ]}</h2>
    <div class="faq narrow">@{[ faq_html(@faqs) ]}</div>
  </div>
</section>
<section class="section area">
  <div class="container">
    <h2 class="title center">Waar wij <span class="hl">rijden</span></h2>
    <div class="cities-grid near">$near</div>
    <p style="margin-top:22px;text-align:center"><a href="/werkgebied/">Bekijk ons hele werkgebied</a></p>
    <h2 class="title center" style="margin-top:44px">Meer <span class="hl">diensten</span></h2>
    <div class="cities-grid near">$others</div>
  </div>
</section>
H
  $body =~ s/\s+$//;
  my $schema = '{"@context": "https://schema.org", "@graph": ['
    .$BIZ->(map { $PLACE{$_}{name} } @FOOT_TOWNS).', {"@type": "Service", "name": '.js($v->{crumb}).', "serviceType": '.js($v->{crumb}).', "provider": {"@id": '.js("$SITE/#business").'}}, '
    .faq_ld(@faqs).', '.crumb_ld($v->{crumb}, $path).']}';
  page(title => $v->{title}, desc => $v->{desc}, path => $path, body => $body, schema => $schema, crumb => $v->{crumb});
}

# ===== Werkgebied =====
my @REGIONS = (
  ['Rijnmond', 'Rotterdam en de Rijnmond', 'Van de ring van Rotterdam tot de havens, Voorne aan Zee en de Hoeksche Waard. Veel tunnels en bruggen, veel vrachtverkeer en een haven die nooit stilstaat.'],
  ['Drechtsteden', 'Drechtsteden en Alblasserwaard', 'De rivierenregio tussen Rotterdam en Brabant, met de A15 en de A16 als drukste routes en de Merwede, de Noord en de Oude Maas ertussen.'],
  ['Brabant', 'Noord-Brabant', 'Van Bergen op Zoom en Roosendaal tot Eindhoven, Helmond en Oss. Langs de A16, de A58, de A2 en de A59 rijdt dag en nacht doorgaand verkeer.'],
  ['Zeeland', 'Zeeland', 'Walcheren, Zuid-Beveland, Schouwen-Duiveland en Zeeuws-Vlaanderen. Lange afstanden en in de zomer veel toeristen met caravan of camper.'],
  ['Rivierenland', 'Rivierenland', 'De Betuwe en de Bommelerwaard, langs de A15 en de A2 aan weerszijden van de Waal.'],
);
sub werkgebied {
  my $secs = '';
  for my $r (@REGIONS) {
    my ($k, $h, $p) = @$r;
    my @s = sort { $PLACE{$a}{name} cmp $PLACE{$b}{name} } grep { $PLACE{$_}{region} eq $k } keys %PLACE;
    die "regio leeg: $k" unless @s;
    $secs .= qq(<h2 class="title">$h</h2>\n    <p>$p</p>\n    <div class="cities-grid near" style="margin:18px 0 40px">).join('', map { card($_) } @s)."</div>\n    ";
  }
  my $body = <<"H";
<section class="hero hero-city">
  <div class="container hero-grid">
    <div>
      <h1>Ons <span>werkgebied</span></h1>
      <p>$NAME helpt 24/7 in Zuidwest-Nederland en het rivierengebied. Staat uw plaats er niet bij? Bel ons toch: vaak kunnen we ook daar helpen, en u hoort meteen of dat lukt en wat het kost.</p>
      <div class="actions">
        <a class="btn btn-yellow" href="tel:$TEL"><svg class="ico"><use href="#i-phone"/></svg>Bel direct: $DISP</a>
      </div>
    </div>
    <div class="hero-art">$ART</div>
  </div>
  $WAVE
</section>
<section class="section area">
  <div class="container">
    $secs
  </div>
</section>
H
  $body =~ s/\s+$//;
  my $path = '/werkgebied/';
  my $schema = '{"@context": "https://schema.org", "@graph": ['.$BIZ->(sort map { $_->{name} } values %PLACE).', '.crumb_ld('Werkgebied', $path).']}';
  page(title => "Werkgebied sleepdienst: alle plaatsen | $NAME",
       desc => "Alle plaatsen waar $NAME 24/7 helpt: Rotterdam, Drechtsteden, Brabant, Zeeland en het rivierengebied. Bel $DISP.",
       path => $path, body => $body, schema => $schema, crumb => 'Werkgebied');
}

# ===== Bestaande pagina's bijwerken =====
my %EXTRA = map { $_->{slug} => $_ } @EXTRA;
for my $s (sort keys %OLD) {
  my $e = $EXTRA{$s} or die "geen extra tekst voor $s\n";
  my $f = "sleepdienst-$s/index.html"; my $h = rd("$ROOT/$f");
  my $n = esc($OLD{$s}[0]);
  my $block = qq(<!--extra--><h3>Pechhulp in $n</h3>\n      <p>).typo($e->{pech}).qq(</p>\n      <h3>Autotransport en berging vanuit $n</h3>\n      <p>).typo($e->{trans}).qq(</p><!--/extra-->\n      );
  $h =~ s{<!--extra-->.*?<!--/extra-->\s*}{}s;
  $h =~ s{(<h3>Wat wij doen in )}{$block$1} or die "$s: geen Wat wij doen";
  my $does = $DOES->($n);
  $h =~ s{<h3>Wat wij doen in .*?</ul>}{$does}s or die "$s: lijst";
  my $near = join '', map { card($_) } split /, /, $e->{near};
  $h =~ s{<div class="cities-grid near">.*?</div>(?:<!--hub-->.*?<!--/hub-->)?}{<div class="cities-grid near">$near</div><!--hub--><p style="margin-top:22px;text-align:center"><a href="/werkgebied/">Bekijk ons hele werkgebied</a></p><!--/hub-->}s or die "$s: near";
  $h =~ s{(<div class="cities">)(.*?)(</div>)}{$1.link_chips($2, $s).$3}se or die "$s: chips";
  wr($f, patch_footer($h));
}
sub town_links {
  my $r = shift;
  join ', ', map { qq(<a href="/sleepdienst-$_/">).esc($PLACE{$_}{name}).'</a>' }
    sort { $PLACE{$a}{name} cmp $PLACE{$b}{name} } grep { $PLACE{$_}{region} eq $r } keys %PLACE;
}
my $ALL_TOWNS = join '', map { "<p><strong>$_->[1]:</strong> ".town_links($_->[0]).'.</p>' } @REGIONS;
{
  my $f = 'pech-op-de-snelweg/index.html'; my $h = rd("$ROOT/$f");
  my $b = qq(<!--links--><h2>Hulp bij u in de buurt</h2>\n      $ALL_TOWNS\n      <p>Lees ook over <a href="/pechhulp/">pechhulp zonder abonnement</a>, <a href="/autoambulance/">de autoambulance</a>, <a href="/bergingsbedrijf/">berging na een ongeval</a>, <a href="/vrachtwagen-berging/">vrachtwagen berging</a> en <a href="/wat-kost-een-sleepdienst/">wat een sleepdienst kost</a>.</p><!--/links-->);
  $h =~ s{<!--links-->.*?<!--/links-->\s*}{}s;
  $h =~ s{(</article>)}{$b\n    $1} or die 'snelweg links';
  wr($f, patch_footer($h));
}
{
  my $f = 'elektrische-auto-slepen/index.html'; my $h = rd("$ROOT/$f");
  my $b = qq(<!--links--><p>Staat uw auto stil door iets anders? Lees over <a href="/starthulp/">starthulp bij een lege accu</a>, <a href="/autoambulance/">de autoambulance</a>, <a href="/autotransport/">autotransport</a>, <a href="/verkeerd-getankt/">verkeerd getankt</a> en <a href="/wat-kost-een-sleepdienst/">wat een sleepdienst kost</a>. Bekijk ook <a href="/werkgebied/">alle plaatsen in ons werkgebied</a>.</p><!--/links-->);
  $h =~ s{<!--links-->.*?<!--/links-->\s*}{}s;
  $h =~ s{(</article>)}{$b\n    $1} or die 'ev links';
  wr($f, patch_footer($h));
}
wr('privacy/index.html', patch_footer(rd("$ROOT/privacy/index.html")));
{
  my $h = rd("$ROOT/index.html");
  my @home = qw(rotterdam eindhoven barendrecht breda dordrecht tilburg den-bosch schiedam rotterdam-zuid gorinchem spijkenisse goes);
  my $grid = join '', map { card($_) } @home;
  $h =~ s{<div class="cities-grid">.*?</div>(?:<!--alle-->.*?<!--/alle-->)?}{<div class="cities-grid">$grid</div><!--alle--><div class="town-links" style="margin-top:18px">$ALL_TOWNS</div><p style="margin-top:18px"><a class="btn btn-navy" href="/werkgebied/">Alle plaatsen in ons werkgebied</a></p><!--/alle-->}s or die 'home grid';
  my $svc = join '', map { svc_card($_) } @SERVICES;
  my $sec = qq(<!--alle-diensten--><section class="section area"><div class="container"><h2 class="title center">Al onze <span class="hl">diensten</span></h2><div class="cities-grid near">$svc</div></div></section><!--/alle-diensten-->\n);
  $h =~ s{<!--alle-diensten-->.*?<!--/alle-diensten-->\s*}{}s;
  $h =~ s{(<section class="section steps-sec")}{$sec$1} or die 'home steps';
  wr('index.html', patch_footer($h));
}

# ===== Nieuwe pagina's schrijven =====
wr("sleepdienst-$_->{slug}/index.html", town_page($_)) for @TOWNS;
wr("$_->{slug}/index.html", service_page($_)) for @SERVICES;
wr('werkgebied/index.html', werkgebied());

printf "Gebouwd: %d nieuwe plaatsen, %d diensten, werkgebied.\n", scalar @TOWNS, scalar @SERVICES;

# Engelse /en/ mirror, hreflang op NL, volledige sitemap (NL+EN)
my $en = system($^X, "$ROOT/build-en.pl");
die "build-en.pl mislukt\n" if $en != 0;
