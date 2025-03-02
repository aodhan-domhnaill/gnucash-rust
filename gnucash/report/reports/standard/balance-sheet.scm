;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; balance-sheet.scm: balance sheet
;; 
;; By Robert Merkel <rgmerk@mira.net>
;;
;; Heavily modified and Frankensteined by David Montenegro 
;;   2004.06.12-2004.06.23 <sunrise2000@comcast.net>
;;  
;;  * Removed from-date & Net Profit from the report.
;;  
;;  * Updated to use the new gnc:html-acct-table utility object.
;;    Added *lots* of new options.  The report can now probably
;;    be coerced into the form that *you* want. <grin>
;;  
;;  * BUGS:
;;    
;;    The Accounts option panel needs a way to select (and select by
;;    default) accounts representative of current & fixed assets &
;;    liabilities.
;;    
;;    This code makes the assumption that you want your balance
;;    sheet to no more than daily resolution.
;;    
;;    Line & column alignments still do not conform with
;;    textbook accounting practice (they're close though!).
;;    
;;    Progress bar functionality is currently mostly broken.
;;    
;;    The variables in this code could use more consistent naming.
;;    
;;    The multicurrency support has been tested, BUT IS ALPHA.  I
;;    *think* it works right, but can make no guarantees....  In
;;    particular, I have made the educated assumption <grin> that a
;;    decrease in the value of a liability or equity also represents
;;    an unrealized loss.  I *think* that is right, but am not sure.
;;    
;;    See also all the "FIXME"s in the code.
;;    
;; Largely borrowed from pnl.scm by:
;; Christian Stimming <stimming@tu-harburg.de>
;;
;; This program is free software; you can redistribute it and/or    
;; modify it under the terms of the GNU General Public License as   
;; published by the Free Software Foundation; either version 2 of   
;; the License, or (at your option) any later version.              
;;                                                                  
;; This program is distributed in the hope that it will be useful,  
;; but WITHOUT ANY WARRANTY; without even the implied warranty of   
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    
;; GNU General Public License for more details.                     
;;                                                                  
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 51 Franklin Street, Fifth Floor    Fax:    +1-617-542-2652
;; Boston, MA  02110-1301,  USA       gnu@gnu.org
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-module (gnucash reports standard balance-sheet))
(use-modules (gnucash engine))
(use-modules (gnucash utilities)) 
(use-modules (gnucash core-utils))
(use-modules (gnucash app-utils))
(use-modules (gnucash report))

(define reportname (N_ "Balance Sheet"))

;; define all option's names and help text so that they are properly
;; defined in *one* place.
(define optname-report-title (N_ "Report Title"))
(define opthelp-report-title (N_ "Title for this report."))

(define optname-date (N_ "Balance Sheet Date"))
(define optname-report-form (N_ "Single column Balance Sheet"))
(define opthelp-report-form
  (N_ "Print liability/equity section in the same column under the assets section as opposed to a second column right of the assets section."))

(define optname-accounts (N_ "Accounts"))
(define opthelp-accounts
  (N_ "Report on these accounts, if display depth allows."))
(define optname-depth-limit (N_ "Levels of Subaccounts"))
(define opthelp-depth-limit
  (N_ "Maximum number of levels in the account tree displayed."))
(define optname-bottom-behavior (N_ "Flatten list to depth limit"))
(define opthelp-bottom-behavior
  (N_ "Displays accounts which exceed the depth limit at the depth limit."))

(define optname-parent-balance-mode (N_ "Parent account balances"))
(define optname-parent-total-mode (N_ "Parent account subtotals"))

(define optname-show-zb-accts (N_ "Include accounts with zero total balances"))
(define opthelp-show-zb-accts
  (N_ "Include accounts with zero total (recursive) balances in this report."))
(define optname-omit-zb-bals (N_ "Omit zero balance figures"))
(define opthelp-omit-zb-bals
  (N_ "Show blank space in place of any zero balances which would be shown."))

(define optname-use-rules (N_ "Show accounting-style rules"))
(define opthelp-use-rules
  (N_ "Use rules beneath columns of added numbers like accountants do."))

(define optname-account-links (N_ "Display accounts as hyperlinks"))
(define opthelp-account-links (N_ "Shows each account in the table as a hyperlink to its register window."))

(define optname-label-assets (N_ "Label the assets section"))
(define opthelp-label-assets
  (N_ "Whether or not to include a label for the assets section."))
(define optname-total-assets (N_ "Include assets total"))
(define opthelp-total-assets
  (N_ "Whether or not to include a line indicating total assets."))
(define optname-standard-order (N_ "Use standard US layout"))
(define opthelp-standard-order
  (N_ "Report section order is assets/liabilities/equity (rather than assets/equity/liabilities)."))
(define optname-label-liabilities (N_ "Label the liabilities section"))
(define opthelp-label-liabilities
  (N_ "Whether or not to include a label for the liabilities section."))
(define optname-total-liabilities (N_ "Include liabilities total"))
(define opthelp-total-liabilities
  (N_ "Whether or not to include a line indicating total liabilities."))
(define optname-label-equity (N_ "Label the equity section"))
(define opthelp-label-equity
  (N_ "Whether or not to include a label for the equity section."))
(define optname-total-equity (N_ "Include equity total"))
(define opthelp-total-equity
  (N_ "Whether or not to include a line indicating total equity."))

(define pagename-commodities (N_ "Commodities"))
(define optname-report-commodity (N_ "Report's currency"))
(define optname-price-source (N_ "Price Source"))
(define optname-show-foreign (N_ "Show Foreign Currencies"))
(define opthelp-show-foreign
  (N_ "Display any foreign currency amount in an account."))
(define optname-show-rates (N_ "Show Exchange Rates"))
(define opthelp-show-rates (N_ "Show the exchange rates used."))


;; options generator
(define (balance-sheet-options-generator)
  (let* ((options (gnc-new-optiondb)))

    (gnc-register-string-option options
      gnc:pagename-general optname-report-title
      "a" opthelp-report-title (G_ reportname))

    ;; date at which to report balance
    (gnc:options-add-report-date!
     options gnc:pagename-general optname-date "c")

    (gnc-register-simple-boolean-option options
      gnc:pagename-general optname-report-form
      "d" opthelp-report-form #t)

    (gnc-register-simple-boolean-option options
       gnc:pagename-general optname-standard-order
       "dd" opthelp-standard-order #t)

    ;; accounts to work on
    (gnc-register-account-list-option options
      gnc:pagename-accounts optname-accounts
      "a"
      opthelp-accounts
      (gnc:filter-accountlist-type
         (list ACCT-TYPE-BANK ACCT-TYPE-CASH ACCT-TYPE-CREDIT
               ACCT-TYPE-ASSET ACCT-TYPE-LIABILITY
               ACCT-TYPE-STOCK ACCT-TYPE-MUTUAL ACCT-TYPE-CURRENCY
               ACCT-TYPE-PAYABLE ACCT-TYPE-RECEIVABLE
               ACCT-TYPE-EQUITY ACCT-TYPE-INCOME ACCT-TYPE-EXPENSE
               ACCT-TYPE-TRADING)
	 (gnc-account-get-descendants-sorted (gnc-get-current-root-account))))
    (gnc:options-add-account-levels!
     options gnc:pagename-accounts optname-depth-limit
     "b" opthelp-depth-limit 3)
    (gnc-register-simple-boolean-option options
      gnc:pagename-accounts optname-bottom-behavior
      "c" opthelp-bottom-behavior #f)

    ;; all about currencies
    (gnc:options-add-currency!
     options pagename-commodities
     optname-report-commodity "a")

    (gnc:options-add-price-source!
     options pagename-commodities
     optname-price-source "b" 'pricedb-nearest)

    (gnc-register-simple-boolean-option options
      pagename-commodities optname-show-foreign
      "c" opthelp-show-foreign #t)

    (gnc-register-simple-boolean-option options
      pagename-commodities optname-show-rates
      "d" opthelp-show-rates #f)

    ;; what to show for zero-balance accounts
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-show-zb-accts
      "a" opthelp-show-zb-accts #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-omit-zb-bals
      "b" opthelp-omit-zb-bals #f)
    ;; what to show for non-leaf accounts
    (gnc:options-add-subtotal-view!
     options gnc:pagename-display
     optname-parent-balance-mode optname-parent-total-mode
     "c")

    ;; some detailed formatting options
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-account-links
      "e" opthelp-account-links #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-use-rules
      "f" opthelp-use-rules #f)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-assets
      "g" opthelp-label-assets #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-assets
      "h" opthelp-total-assets #t)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-liabilities
      "i" opthelp-label-liabilities #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-liabilities
      "j" opthelp-total-liabilities #t)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-equity
      "k" opthelp-label-equity #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-equity
      "l" opthelp-total-equity #t)

    ;; Set the accounts page as default option tab
    (gnc:options-set-default-section options gnc:pagename-accounts)

    options))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; balance-sheet-renderer
;; set up the document and add the table
;; then return the document or, if
;; requested, export it to a file
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (balance-sheet-renderer report-obj)
  (define (get-option pagename optname)
    (gnc-optiondb-lookup-value
      (gnc:report-options report-obj) pagename optname))

  (gnc:report-starting reportname)

  ;; get all option's values
  (let* (
         (report-title (get-option gnc:pagename-general optname-report-title))
         (company-name (or (gnc:company-info (gnc-get-current-book) gnc:*company-name*) ""))
         (reportdate (gnc:time64-end-day-time
                      (gnc:date-option-absolute-time
                       (get-option gnc:pagename-general optname-date))))
         (report-form? (get-option gnc:pagename-general optname-report-form))
         (standard-order? (get-option gnc:pagename-general optname-standard-order))
         (use-trading-accts? (qof-book-use-trading-accounts (gnc-get-current-book)))
         (accounts (get-option gnc:pagename-accounts optname-accounts))
         (depth-limit (get-option gnc:pagename-accounts optname-depth-limit))
         (bottom-behavior (get-option gnc:pagename-accounts optname-bottom-behavior))
         (report-commodity (get-option pagename-commodities optname-report-commodity))
         (price-source (get-option pagename-commodities optname-price-source))
         (show-fcur? (get-option pagename-commodities optname-show-foreign))
         (show-rates? (get-option pagename-commodities optname-show-rates))
         (parent-balance-mode (get-option gnc:pagename-display
                                          optname-parent-balance-mode))
         (parent-total-mode
          (assq-ref '((t . #t) (f . #f))
                    (get-option gnc:pagename-display optname-parent-total-mode)))
         (show-zb-accts? (get-option gnc:pagename-display optname-show-zb-accts))
         (omit-zb-bals? (get-option gnc:pagename-display optname-omit-zb-bals))
         (label-assets? (get-option gnc:pagename-display optname-label-assets))
         (total-assets? (get-option gnc:pagename-display optname-total-assets))
         (label-liabilities?
          (get-option gnc:pagename-display optname-label-liabilities))
         (total-liabilities?
          (get-option gnc:pagename-display optname-total-liabilities))
         (label-equity? (get-option gnc:pagename-display optname-label-equity))
         (total-equity? (get-option gnc:pagename-display optname-total-equity))
         (use-links? (get-option gnc:pagename-display optname-account-links))
         (use-rules? (get-option gnc:pagename-display optname-use-rules))

         ;; decompose the account list
         (split-up-accounts (gnc:decompose-accountlist accounts))
         (asset-accounts (assoc-ref split-up-accounts ACCT-TYPE-ASSET))
         (liability-accounts (assoc-ref split-up-accounts ACCT-TYPE-LIABILITY))
         (income-expense-accounts
          (append (assoc-ref split-up-accounts ACCT-TYPE-INCOME)
                  (assoc-ref split-up-accounts ACCT-TYPE-EXPENSE)))
         (equity-accounts (assoc-ref split-up-accounts ACCT-TYPE-EQUITY))
         (trading-accounts (assoc-ref split-up-accounts ACCT-TYPE-TRADING))

         (doc (gnc:make-html-document))
         ;; this can occasionally put extra (blank) columns in our
         ;; table (when there is one account at the maximum depth and
         ;; it has at least one of its ancestors deselected), but this
         ;; is the only simple way to ensure that all three tables
         ;; (asset, liability, equity) have the same width.
         (tree-depth (if (eq? depth-limit 'all)
                         (gnc:get-current-account-tree-depth)
                         depth-limit))
         (price-fn (gnc:case-price-fn price-source report-commodity reportdate))
         ;; exchange rates calculation parameters
         (exchange-fn
          (gnc:case-exchange-fn price-source report-commodity reportdate)))

    ;; Wrapper to call gnc:html-table-add-labeled-amount-line!
    ;; with the proper arguments.
    (define (add-subtotal-line table pos-label neg-label signed-balance)
      (let* ((neg? (and signed-balance neg-label
                        (negative?
                         (gnc:gnc-monetary-amount
                          (gnc:sum-collector-commodity
                           signed-balance report-commodity exchange-fn)))))
             (label (if neg? (or neg-label pos-label) pos-label))
             (balance (if neg? (gnc:collector- signed-balance) signed-balance)))
        (gnc:html-table-add-labeled-amount-line!
         table (* tree-depth 2) "primary-subheading" #f label 0 1 "total-label-cell"
         (gnc:sum-collector-commodity balance report-commodity exchange-fn)
         (1- (* tree-depth 2)) 1 "total-number-cell")))

    ;; Wrapper around gnc:html-table-append-ruler! since we call it so
    ;; often.
    (define (add-rule table)
      (gnc:html-table-append-ruler! table (* 2 tree-depth)))

    ;; Return a commodity collector containing the sum of the balance of all of
    ;; the accounts on acct-list as of the time given in reportdate
    (define (account-list-balance acct-list reportdate)
      (define (acc->balance acc)
        (gnc:make-gnc-monetary
         (xaccAccountGetCommodity acc)
         (xaccAccountGetBalanceAsOfDate acc reportdate)))
      (apply gnc:monetaries-add (map acc->balance acct-list)))

    ;; Format the liabilities section of the report
    (define (add-liability-block
             label-liabilities? parent-table table-env liability-accounts params
             total-liabilities? liability-balance)
      (let* ((liability-table
              (gnc:make-html-acct-table/env/accts table-env liability-accounts)))
        (when label-liabilities?
          (add-subtotal-line  parent-table (G_ "Liabilities") #f #f))
        (gnc:html-table-add-account-balances parent-table liability-table params)
        (when total-liabilities?
          (add-subtotal-line
           parent-table (G_ "Total Liabilities") #f liability-balance))
        (add-rule parent-table)))

    (define (get-total-value-fn account)
      (gnc:account-get-comm-value-at-date account reportdate #f))

    (gnc:html-document-set-title!
     doc (string-append company-name " " report-title " "
                        (qof-print-date reportdate)))

    (if (null? accounts)

        ;; error condition: no accounts specified
        ;; is this *really* necessary??
        ;; i'd be fine with an all-zero balance sheet
        ;; that would, technically, be correct....
        (gnc:html-document-add-object!
         doc (gnc:html-make-no-account-warning reportname (gnc:report-id report-obj)))

        ;; Get all the balances for each of the account types.
        (let* ((asset-balance
                (account-list-balance asset-accounts reportdate))

               (liability-balance
                (gnc:collector- (account-list-balance liability-accounts reportdate)))

               (equity-balance
                (gnc:collector- (account-list-balance equity-accounts reportdate)))

               (retained-earnings
                (gnc:collector-
                 (account-list-balance income-expense-accounts reportdate)))

               (trading-balance
                (if use-trading-accts?
                    (gnc:collector- (account-list-balance trading-accounts reportdate))
                    (gnc:collector+)))

               (unrealized-gain-collector
                (if use-trading-accts?
                    (gnc:collector+)
                    (gnc:collector- asset-balance
                                    liability-balance
                                    (gnc:accounts-get-comm-total-assets
                                     (append asset-accounts liability-accounts)
                                     get-total-value-fn))))

               (total-equity-balance
                (gnc:collector+ equity-balance retained-earnings
                                unrealized-gain-collector trading-balance))

               (liability-plus-equity
                (gnc:collector+ liability-balance total-equity-balance))

               ;; Create the account tables below where their
               ;; percentage time can be tracked.
               (left-table (gnc:make-html-table)) ;; gnc:html-table
               (right-table (if report-form?
                                left-table
                                (gnc:make-html-table)))

               (table-env
                (list
                 (list 'start-date #f)
                 (list 'end-date reportdate)
                 (list 'display-tree-depth tree-depth)
                 (list 'depth-limit-behavior (if bottom-behavior 'flatten 'summarize))
                 (list 'report-commodity report-commodity)
                 (list 'exchange-fn exchange-fn)
                 (list 'parent-account-subtotal-mode parent-total-mode)
                 (list 'zero-balance-mode
                       (if show-zb-accts? 'show-leaf-acct 'omit-leaf-acct))
                 (list 'account-label-mode (if use-links? 'anchor 'name))))

               (params
                (list
                 (list 'parent-account-balance-mode parent-balance-mode)
                 (list 'zero-balance-display-mode
                       (if omit-zb-bals? 'omit-balance 'show-balance))
                 (list 'multicommodity-mode (and show-fcur? 'table))
                 (list 'rule-mode use-rules?)))

               (asset-table
                (gnc:make-html-acct-table/env/accts table-env asset-accounts))

               (equity-table
                (gnc:make-html-acct-table/env/accts table-env equity-accounts)))

          (let ((space (make-list tree-depth (gnc:make-html-table-cell/min-width 60))))
            (gnc:html-table-append-row! left-table space)
            (unless report-form?
              (gnc:html-table-append-row! right-table space)))
          (gnc:report-percent-done 80)

          (when label-assets?
            (add-subtotal-line left-table (G_ "Assets") #f #f))
          (gnc:html-table-add-account-balances left-table asset-table params)
          (when total-assets?
            (add-subtotal-line left-table (G_ "Total Assets") #f asset-balance))

          (when report-form?
            (add-rule left-table)
            (add-rule left-table))
          (gnc:report-percent-done 85)

          (when standard-order?
            (add-liability-block label-liabilities? right-table table-env
                                 liability-accounts params
                                 total-liabilities? liability-balance))
          (gnc:report-percent-done 88)

          (when label-equity?
            (add-subtotal-line right-table (G_ "Equity") #f #f))
          (gnc:html-table-add-account-balances right-table equity-table params)
          ;; we omit retained earnings & unrealized gains
          ;; from the balance report, if zero, since they
          ;; are not present on normal balance sheets
          (unless (gnc-commodity-collector-allzero? retained-earnings)
            (add-subtotal-line right-table
                               (G_ "Retained Earnings")
                               (G_ "Retained Losses")
                               retained-earnings))
          (unless (gnc-commodity-collector-allzero? trading-balance)
            (add-subtotal-line right-table
                               (G_ "Trading Gains")
                               (G_ "Trading Losses")
                               trading-balance))
          (unless (gnc-commodity-collector-allzero? unrealized-gain-collector)
            (add-subtotal-line right-table
                               (G_ "Unrealized Gains")
                               (G_ "Unrealized Losses")
                               unrealized-gain-collector))
          (when total-equity?
            (add-subtotal-line
             right-table (G_ "Total Equity") #f total-equity-balance))

          (add-rule right-table)

          (unless standard-order?
            (add-liability-block label-liabilities? right-table table-env
                                 liability-accounts params
                                 total-liabilities? liability-balance))

          (add-subtotal-line
           right-table (gnc:html-string-sanitize (G_ "Total Liabilities & Equity"))
           #f liability-plus-equity)

          (gnc:html-document-add-object!
           doc (if report-form?
                   left-table
                   (let ((build-table (gnc:make-html-table)))
                     (gnc:html-table-append-row!
                      build-table (list left-table right-table))
                     (gnc:html-table-set-style!
                      build-table "td"
                      'attribute '("align" "left")
                      'attribute '("valign" "top"))
                     build-table)))

          ;; add currency information if requested
          (gnc:report-percent-done 90)
          (when show-rates?
            (gnc:html-document-add-object!
             doc (gnc:html-make-rates-table report-commodity price-fn accounts)))

          (gnc:report-percent-done 100)))

    (gnc:report-finished)

    doc))

(gnc:define-report
 'version 1
 'name reportname
 'report-guid "c4173ac99b2b448289bf4d11c731af13"
 'menu-path (list gnc:menuname-asset-liability)
 'options-generator balance-sheet-options-generator
 'renderer balance-sheet-renderer)

;; END
