import { LightningElement, api, wire } from 'lwc';
import getMarginData from '@salesforce/apex/VelQuoteMarginController.getMarginData';

const CURRENCY_FMT = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});
const PCT_FMT = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1
});

function fmtCurrency(val) {
    return val != null ? CURRENCY_FMT.format(val) : 'N/A';
}

function fmtPct(val) {
    return val != null ? PCT_FMT.format(val) + '%' : 'N/A';
}

function badgeClass(pct) {
    if (pct == null)  return 'vel-badge vel-badge-na';
    if (pct >= 30)    return 'vel-badge vel-badge-green';
    if (pct >= 15)    return 'vel-badge vel-badge-amber';
    if (pct >= 0)     return 'vel-badge vel-badge-red';
    return 'vel-badge vel-badge-negative';
}

function iconName(pct) {
    if (pct == null)  return 'utility:help';
    if (pct >= 30)    return 'utility:success';
    if (pct >= 15)    return 'utility:warning';
    return 'utility:error';
}

export default class VelQuoteMargin extends LightningElement {
    @api recordId;

    _rows = null;
    isLoading = true;
    error;

    @wire(getMarginData, { quoteId: '$recordId' })
    wired({ data, error }) {
        this.isLoading = false;
        if (data) {
            this._rows = data.map(r => ({
                ...r,
                formattedNetPrice  : fmtCurrency(r.netTotalPrice),
                formattedCost      : r.totalCost != null ? fmtCurrency(r.totalCost) : 'N/A',
                formattedMarginAmt : fmtCurrency(r.marginAmount),
                formattedMarginPct : fmtPct(r.marginPct),
                badgeClass         : badgeClass(r.marginPct),
                iconName           : iconName(r.marginPct),
                hasCost            : r.unitCost != null
            }));
        }
        if (error) {
            this.error = error.body?.message ?? 'Failed to load margin data.';
        }
    }

    get rows()    { return this._rows; }
    get hasRows() { return Array.isArray(this._rows) && this._rows.length > 0; }
    get isEmpty() { return !this.isLoading && !this.error && Array.isArray(this._rows) && this._rows.length === 0; }
    get hasError(){ return !this.isLoading && Boolean(this.error); }
    get hasMissingCost() { return this._rows?.some(r => !r.hasCost) ?? false; }

    // ── Totals row ──────────────────────────────────────────────────────────
    get _sumNetPrice()    { return this._rows?.reduce((s, r) => s + (r.netTotalPrice ?? 0), 0) ?? 0; }
    get _sumCost()        { return this._rows?.reduce((s, r) => s + (r.totalCost     ?? 0), 0) ?? 0; }
    get _sumMarginAmt()   { return this._sumNetPrice - this._sumCost; }
    get _totalMarginPct() {
        const n = this._sumNetPrice;
        return n !== 0 ? parseFloat(((n - this._sumCost) / n * 100).toFixed(1)) : null;
    }

    get totalNetPrice()    { return fmtCurrency(this._sumNetPrice); }
    get totalCost()        { return fmtCurrency(this._sumCost); }
    get totalMarginAmount(){ return fmtCurrency(this._sumMarginAmt); }
    get totalMarginPct()   { return fmtPct(this._totalMarginPct); }
    get totalBadgeClass()  { return badgeClass(this._totalMarginPct); }
    get totalIconName()    { return iconName(this._totalMarginPct); }
}
