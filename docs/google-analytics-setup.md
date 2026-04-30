# Google Analytics 4 Integration for Yojana

This document explains how to set up Google Analytics 4 for Yojana.

## Overview

Google Analytics 4 (GA4) has been integrated into Yojana using OpenProject's settings system. This allows administrators to configure the GA Measurement ID from the admin interface without code changes.

## Configuration Steps

### 1. Get Google Analytics 4 Measurement ID

1. Go to [Google Analytics](https://analytics.google.com/)
2. Create a new property or select existing one
3. Navigate to **Admin** → **Data Streams** → **Web**
4. Copy the **Measurement ID** (format: `G-XXXXXXXXXX`)

### 2. Configure in Yojana Admin

1. Login to Yojana as admin
2. Go to **Administration** → **System Settings** → **General**
3. Scroll down to **Google Analytics 4 Measurement ID**
4. Enter your Measurement ID (e.g., `G-XXXXXXXXXX`)
5. Click **Save**

### 3. Verify Installation

1. Open your Yojana site in browser (https://yojana.girishm.info)
2. Open browser Developer Tools (F12) → Network tab
3. Filter by "google" or "gtag"
4. You should see requests to:
   - `https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX`
   - `https://www.google-analytics.com/g/collect?...`

5. Check Google Analytics Real-Time reports to confirm data is flowing

## Technical Implementation

### Files Modified

1. **`config/constants/settings/definition.rb`**
   - Added `google_analytics_id` setting (format: string, default: nil)

2. **`app/views/common/_google_analytics.html.erb`** (new file)
   - Partial that renders GA4 script only when Measurement ID is configured
   - Uses `Setting.google_analytics_id` to check if enabled

3. **`app/views/layouts/_common_head.html.erb`**
   - Added `<%= render partial: "common/google_analytics" %>` to include GA on all pages

4. **`config/initializers/content_security_policy.rb`**
   - Added CSP rules to allow Google Analytics scripts and connections:
     - `script_src`: `https://www.googletagmanager.com`, `https://www.google-analytics.com`
     - `connect_src`: `https://www.google-analytics.com`, `https://stats.g.doubleclick.net`

5. **`app/forms/admin/settings/general_settings_form.rb`**
   - Added text field for `google_analytics_id` in admin settings form

6. **`config/locales/en.yml`**
   - Added translation: `setting_google_analytics_id: "Google Analytics 4 Measurement ID"`

### How It Works

1. **Admin sets Measurement ID**: Administrator enters GA4 Measurement ID in System Settings
2. **Setting saved**: Stored in `settings` table as `google_analytics_id`
3. **Page loads**: Layout renders `_common_head.html.erb`
4. **GA partial called**: `_google_analytics.html.erb` checks if `Setting.google_analytics_id.present?`
5. **Script injected**: If ID exists, GA4 script and config are added to page head
6. **CSP allows**: Content Security Policy permits GA scripts and connections

## Disabling Google Analytics

To disable Google Analytics:

1. Go to **Administration** → **System Settings** → **General**
2. Clear the **Google Analytics 4 Measurement ID** field
3. Click **Save**

The GA script will no longer be included in pages.

## Troubleshooting

### GA Not Working

1. **Check Measurement ID format**: Should be `G-XXXXXXXXXX` (not UA-...)
2. **Check CSP errors**: Open browser console for Content Security Policy violations
3. **Verify setting saved**: Check `Setting.google_analytics_id` in Rails console
4. **Clear cache**: Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)

### CSP Violations

If you see CSP errors in browser console:

1. Check that `config/initializers/content_security_policy.rb` has GA domains whitelisted
2. Restart Rails server after any CSP changes
3. Verify no proxy/CDN is stripping CSP headers

### Testing in Development

Google Analytics will work in development if:
- You have a valid Measurement ID configured
- Your development environment is accessible from the internet (or use GA's debug mode)

To test without real GA:
1. Use GA4 DebugView
2. Install Google Analytics Debugger Chrome extension
3. Check browser console for GA debug messages

## Privacy Considerations

- Google Analytics collects visitor data (IP addresses, user agents, etc.)
- Consider updating your privacy policy to disclose GA usage
- Consider implementing cookie consent banner if required by GDPR/local laws
- You can anonymize IP addresses in GA admin settings

## References

- [Google Analytics 4 Documentation](https://support.google.com/analytics/answer/10089681)
- [GA4 Measurement ID vs Tracking ID](https://support.google.com/analytics/answer/9539598)
- [Content Security Policy for GA](https://developers.google.com/tag-manager/web/csp)
