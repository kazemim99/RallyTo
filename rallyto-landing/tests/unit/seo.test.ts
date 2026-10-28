import { describe, expect, it } from 'vitest'
import { breadcrumbLd, mobileApplicationLd, organizationLd, websiteLd } from '../../src/lib/seo'

// Structured data: only what search engines use, only what is true.

describe('JSON-LD', () => {
  it('names the organization and the site «رالیتو», with the Latin name as alternate', () => {
    const org = organizationLd()
    expect(org).toMatchObject({ '@type': 'Organization', name: 'رالیتو', alternateName: 'Rallyto', url: 'https://rallyto.ir/' })
    expect(org.logo).toMatch(/^https:\/\/rallyto\.ir\/.+\.png$/)
    expect(websiteLd()).toMatchObject({ '@type': 'WebSite', name: 'رالیتو', url: 'https://rallyto.ir/', inLanguage: 'fa-IR' })
  })

  it('has no search box action (retired by Google in 2024)', () => {
    expect(JSON.stringify(websiteLd())).not.toContain('SearchAction')
  })

  it('describes the Android app without a price or a rating', () => {
    const app = mobileApplicationLd()
    expect(app).toMatchObject({ '@type': 'MobileApplication', operatingSystem: 'ANDROID', applicationCategory: 'SportsApplication' })
    expect(JSON.stringify(app)).not.toMatch(/offers|aggregateRating|price/i)
  })

  it('numbers breadcrumbs from 1 with absolute URLs', () => {
    const ld = breadcrumbLd([
      { name: 'رالیتو', path: '/' },
      { name: 'تنیس', path: '/tennis' },
    ])
    expect(ld.itemListElement).toEqual([
      { '@type': 'ListItem', position: 1, name: 'رالیتو', item: 'https://rallyto.ir/' },
      { '@type': 'ListItem', position: 2, name: 'تنیس', item: 'https://rallyto.ir/tennis' },
    ])
  })
})
