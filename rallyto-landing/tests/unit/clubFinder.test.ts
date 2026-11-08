import { describe, expect, it } from 'vitest'
import { filteredTitle, finderTarget, sportFromSearch } from '../../src/lib/clubFinder'

/** Where the club finder goes: the chosen sport must never be dropped on the way to the results. */
describe('finderTarget', () => {
  const choice = { action: '/clubs', sport: '', province: '', city: '', citySports: [] as string[] }

  it('opens the sport page of a city that has the sport', () => {
    expect(finderTarget({ ...choice, sport: 'tennis', province: '/clubs/تهران', city: '/clubs/تهران/تهران', citySports: ['tennis', 'padel'] })).toBe('/clubs/تهران/تهران/tennis#results')
  })

  it('opens a province filtered to the sport when no city is chosen', () => {
    expect(finderTarget({ ...choice, sport: 'tennis', province: '/clubs/تهران' })).toBe('/clubs/تهران?sport=tennis#results')
  })

  it('opens the whole province or city when no sport is chosen', () => {
    expect(finderTarget({ ...choice, province: '/clubs/تهران' })).toBe('/clubs/تهران#results')
    expect(finderTarget({ ...choice, province: '/clubs/تهران', city: '/clubs/تهران/پردیس', citySports: ['badminton'] })).toBe('/clubs/تهران/پردیس#results')
  })

  it('opens the directory at the sport when only a sport is chosen, and the directory when nothing is', () => {
    expect(finderTarget({ ...choice, sport: 'padel' })).toBe('/clubs#padel')
    expect(finderTarget(choice)).toBe('/clubs')
  })
})

describe('sportFromSearch', () => {
  const known = ['tennis', 'padel', 'badminton', 'squash']

  it('reads a sport the site has', () => {
    expect(sportFromSearch('?sport=tennis', known)).toBe('tennis')
  })

  it('ignores a missing or unknown sport, so a bad link shows every club', () => {
    expect(sportFromSearch('', known)).toBeNull()
    expect(sportFromSearch('?sport=golf', known)).toBeNull()
  })
})

describe('filteredTitle', () => {
  it('names the sport and counts only its clubs, in Persian digits', () => {
    expect(filteredTitle(12, 'تنیس', 'استان تهران')).toBe('۱۲ باشگاه تنیس در استان تهران')
  })

  it('says so when the place has no club for the sport', () => {
    expect(filteredTitle(0, 'پدل', 'استان ایلام')).toBe('باشگاه پدل در استان ایلام ثبت نشده')
  })
})
