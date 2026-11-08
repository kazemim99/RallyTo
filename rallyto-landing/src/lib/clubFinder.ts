// The club finder's decisions, apart from the page: where a choice leads, and how a sport-filtered list reads.

export interface FinderChoice {
  /** The directory's path, the form's action. */
  action: string
  sport: string
  province: string
  city: string
  /** The sports the chosen city has clubs for. */
  citySports: readonly string[]
}

/**
 * The page a choice opens. A city has a page per sport; a province has one page, which a `sport` parameter filters in
 * the browser (the parameter changes nothing a search engine sees, so the province keeps one canonical page).
 * A page with results opens on them, past the finder that takes the whole first screen of a phone.
 */
export function finderTarget({ action, sport, province, city, citySports }: FinderChoice): string {
  if (city) return `${citySports.includes(sport) ? `${city}/${sport}` : city}#results`
  if (province) return `${province}${sport ? `?sport=${sport}` : ''}#results`
  return sport ? `${action}#${sport}` : action
}

/** The sport a page's address asks for, if the site has it. Anything else shows every club. */
export function sportFromSearch(search: string, known: readonly string[]): string | null {
  const sport = new URLSearchParams(search).get('sport')
  return sport && known.includes(sport) ? sport : null
}

/** The list's title while it shows one sport's clubs. */
export function filteredTitle(count: number, sportName: string, place: string): string {
  return count > 0 ? `${count.toLocaleString('fa-IR')} باشگاه ${sportName} در ${place}` : `باشگاه ${sportName} در ${place} ثبت نشده`
}
