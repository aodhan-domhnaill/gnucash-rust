;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; budget-balance-sheet.scm: balance sheet from budget projections
;; Based on balance-sheet.scm.
;;
;; Copyright (c) the following:
;;
;;  Forest Bond <forest@alittletooquiet.net>
;;  Robert Merkel <rgmerk@mira.net>
;;  David Montenegro <sunrise2000@comcast.net>
;;  Christian Stimming <stimming@tu-harburg.de>
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

(define-module (gnucash reports standard budget-balance-sheet))
(use-modules (gnucash engine))
(use-modules (gnucash utilities))
(use-modules (gnucash core-utils))
(use-modules (gnucash app-utils))
(use-modules (gnucash report))

(define reportname (N_ "Budget Balance Sheet"))

;; define all option's names and help text so that they are properly
;; defined in *one* place.
(define optname-report-title (N_ "Report Title"))
(define opthelp-report-title (N_ "Title for this report."))

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
(define optname-new-existing (N_ "Include new/existing totals"))
(define opthelp-new-existing
  (N_ "Whether or not to include lines indicating change in totals introduced by budget."))

(define pagename-commodities (N_ "Commodities"))
(define optname-report-commodity (N_ "Report's currency"))
(define optname-price-source (N_ "Price Source"))
(define optname-show-foreign (N_ "Show Foreign Currencies"))
(define opthelp-show-foreign
  (N_ "Display any foreign currency amount in an account."))
(define optname-show-rates (N_ "Show Exchange Rates"))
(define opthelp-show-rates (N_ "Show the exchange rates used."))

(define optname-budget (N_ "Budget"))
(define opthelp-budget (N_ "Budget to use."))


;; options generator
(define (budget-balance-sheet-options-generator)
  (let* ((options (gnc-new-optiondb)))

    (gnc-register-string-option options
      gnc:pagename-general optname-report-title
      "a" opthelp-report-title (G_ reportname))
    
    (gnc-register-simple-boolean-option options
      gnc:pagename-general optname-report-form
      "c" opthelp-report-form #t)

    (gnc-register-budget-option options
      gnc:pagename-general optname-budget
      "d" opthelp-budget (gnc-budget-get-default (gnc-get-current-book)))
    
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
               ACCT-TYPE-EQUITY ACCT-TYPE-INCOME ACCT-TYPE-EXPENSE)
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
      "d" opthelp-account-links #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-use-rules
      "e" opthelp-use-rules #f)
    
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-assets
      "f" opthelp-label-assets #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-assets
      "g" opthelp-total-assets #t)
    
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-liabilities
      "h" opthelp-label-liabilities #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-liabilities
      "i" opthelp-total-liabilities #t)
    
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-label-equity
      "j" opthelp-label-equity #t)
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-total-equity
      "k" opthelp-total-equity #t)

    (gnc-register-simple-boolean-option options
       gnc:pagename-display optname-new-existing
       "l" opthelp-new-existing #t)
    
    ;; Set the accounts page as default option tab
    (gnc:options-set-default-section options gnc:pagename-accounts)
    
    options))

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; budget-balance-sheet-renderer
;; set up the document and add the table
;; then return the document or, if
;; requested, export it to a file
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (budget-balance-sheet-renderer report-obj)
  (define (get-option pagename optname)
    (gnc-optiondb-lookup-value
      (gnc:report-options report-obj) pagename optname))

  (define (get-budget-account-budget-balance budget account)
    (let ((bal (gnc:budget-account-get-net budget account #f #f)))
      (if (gnc-reverse-balance account) (gnc:collector- bal) bal)))

  (define (get-budget-account-initial-balance budget account)
    (gnc:budget-account-get-initial-balance budget account))

  (define (get-budget-accountlist-budget-balance budget accountlist)
    (gnc:budget-accountlist-get-net budget accountlist #f #f))

  (define (get-assoc-account-balances-budget budget accountlist get-balance-fn)
    (gnc:get-assoc-account-balances
      accountlist
      (lambda (account) (get-balance-fn budget account))))

  (define (get-assoc-account-balances-total-negated account-balances)
    (gnc:commodity-collector-get-negated
      (gnc:get-assoc-account-balances-total account-balances)))

  (define (sum-prefetched-account-balances-for-account
           initial-balances budget-balances account)
    (let ((initial (gnc:select-assoc-account-balance initial-balances account))
          (budget (gnc:select-assoc-account-balance budget-balances account)))
      (and initial budget (gnc:collector+ initial budget))))

  (gnc:report-starting reportname)
  
  ;; get all option's values
  (let* (
	 (report-title (get-option gnc:pagename-general optname-report-title))
	 (company-name (or (gnc:company-info (gnc-get-current-book) gnc:*company-name*) ""))
         (budget (get-option gnc:pagename-general optname-budget))
         (budget-valid? (and budget (not (null? budget))))
         (date-t64 (if budget-valid? (gnc:budget-get-start-date budget) #f))
         (report-form? (get-option gnc:pagename-general
                               optname-report-form))
         (accounts (get-option gnc:pagename-accounts
                               optname-accounts))	 
	 (depth-limit (get-option gnc:pagename-accounts 
				  optname-depth-limit))
	 (bottom-behavior (get-option gnc:pagename-accounts 
				  optname-bottom-behavior))
         (report-commodity (get-option pagename-commodities
                                      optname-report-commodity))
         (price-source (get-option pagename-commodities
                                   optname-price-source))
         (show-fcur? (get-option pagename-commodities
                                 optname-show-foreign))
         (show-rates? (get-option pagename-commodities
                                  optname-show-rates))
         (parent-balance-mode (get-option gnc:pagename-display
                                           optname-parent-balance-mode))
         (parent-total-mode
	  (assq-ref '((t . #t) (f . #f))
		    (get-option gnc:pagename-display
				optname-parent-total-mode)))
         (show-zb-accts? (get-option gnc:pagename-display
				     optname-show-zb-accts))
         (omit-zb-bals? (get-option gnc:pagename-display
				    optname-omit-zb-bals))
         (label-assets? (get-option gnc:pagename-display
				    optname-label-assets))
         (total-assets? (get-option gnc:pagename-display
				    optname-total-assets))
         (label-liabilities? (get-option gnc:pagename-display
				    optname-label-liabilities))
         (total-liabilities? (get-option gnc:pagename-display
				    optname-total-liabilities))
         (label-equity? (get-option gnc:pagename-display
				    optname-label-equity))
         (total-equity? (get-option gnc:pagename-display
				    optname-total-equity))
         (new-existing? (get-option gnc:pagename-display
                                    optname-new-existing))
         (use-links? (get-option gnc:pagename-display
				     optname-account-links))
         (use-rules? (get-option gnc:pagename-display
				    optname-use-rules))
	 
         ;; decompose the account list
         (split-up-accounts (gnc:decompose-accountlist accounts))
         (asset-accounts (assoc-ref split-up-accounts ACCT-TYPE-ASSET))
         (liability-accounts (assoc-ref split-up-accounts ACCT-TYPE-LIABILITY))
         (income-accounts (assoc-ref split-up-accounts ACCT-TYPE-INCOME))
         (expense-accounts (assoc-ref split-up-accounts ACCT-TYPE-EXPENSE))
         (equity-accounts (assoc-ref split-up-accounts ACCT-TYPE-EQUITY))
	 
         (doc (gnc:make-html-document))
	 ;; this can occasionally put extra (blank) columns in our
	 ;; table (when there is one account at the maximum depth and
	 ;; it has at least one of its ancestors deselected), but this
	 ;; is the only simple way to ensure that all three tables
	 ;; (asset, liability, equity) have the same width.
         (tree-depth (if (equal? depth-limit 'all)
                         (gnc:get-current-account-tree-depth) 
			 depth-limit))

         ;; exchange rates calculation parameters
	 (exchange-fn
	  (gnc:case-exchange-fn price-source report-commodity date-t64))

         (price-fn (gnc:case-price-fn price-source report-commodity date-t64)))
    
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
      (gnc:html-table-append-ruler!
       table (* 2 tree-depth)))

    (cond
      ((null? accounts)
        ;; No accounts selected.
        (gnc:html-document-add-object! 
         doc 
         (gnc:html-make-no-account-warning 
	  reportname (gnc:report-id report-obj))))
      ((not budget-valid?)
        ;; No budget selected.
        (gnc:html-document-add-object!
          doc (gnc:html-make-generic-budget-warning reportname)))
      (else (begin
        ;; Get all the balances for each of the account types.
        (let* ((asset-balance #f)
               (asset-account-initial-balances #f)
               (asset-account-budget-balances #f)

               (liability-account-initial-balances #f)
               (liability-account-budget-balances #f)

               (equity-account-initial-balances #f)
               (equity-account-budget-balances #f)

               (existing-assets #f)
               (allocated-assets #f)
               (unallocated-assets #f)
               (asset-get-balance-fn #f)

               (existing-liabilities #f)
               (new-liabilities #f)
               (liability-repayments #f)
               (liability-balance #f)
               (liability-get-balance-fn #f)

               (unrealized-gain #f)
               (existing-equity #f)
               (new-equity #f)
               (equity-balance #f)
               (equity-get-balance-fn #f)

               (new-retained-earnings #f)
               (existing-retained-earnings #f)
               (retained-earnings #f)

               (liability-plus-equity #f)
	       
	       (table-env #f)                      ;; parameters for :make-
	       (params #f)                         ;; and -add-account-
               (asset-table #f)                    ;; gnc:html-acct-table
               (liability-table #f)                ;; gnc:html-acct-table
               (equity-table #f)                   ;; gnc:html-acct-table

               ;; Create the account tables below where their
               ;; percentage time can be tracked.
	       (left-table (gnc:make-html-table)) ;; gnc:html-table
	       (right-table (if report-form? left-table
				(gnc:make-html-table)))

               (budget-name (gnc-budget-get-name budget))
	       )
	  

	  (gnc:report-percent-done 4)


          ;; Get asset account balances (positive).

          (set! asset-account-initial-balances
            (get-assoc-account-balances-budget
              budget
              asset-accounts
              get-budget-account-initial-balance))

          (set! asset-account-budget-balances
            (get-assoc-account-balances-budget
              budget
              asset-accounts
              get-budget-account-budget-balance))

          (set! asset-get-balance-fn
            (lambda (account start-date end-date)
              (sum-prefetched-account-balances-for-account
                asset-account-initial-balances
                asset-account-budget-balances
                account)))


	  (gnc:report-percent-done 6)


          ;; Get liability account balances (negative).

          (set! liability-account-initial-balances
            (get-assoc-account-balances-budget
              budget
              liability-accounts
              get-budget-account-initial-balance))

          (set! liability-account-budget-balances
            (get-assoc-account-balances-budget
              budget
              liability-accounts
              get-budget-account-budget-balance))

          (set! liability-get-balance-fn
            (lambda (account start-date end-date)
              (sum-prefetched-account-balances-for-account
                liability-account-initial-balances
                liability-account-budget-balances
                account)))


	  (gnc:report-percent-done 8)


          ;; Get equity account balances (negative).

          (set! equity-account-initial-balances
            (get-assoc-account-balances-budget
              budget
              equity-accounts
              get-budget-account-initial-balance))

          (set! equity-account-budget-balances
            (get-assoc-account-balances-budget
              budget
              equity-accounts
              get-budget-account-budget-balance))

          (set! equity-get-balance-fn
            (lambda (account start-date end-date)
              (sum-prefetched-account-balances-for-account
                equity-account-initial-balances
                equity-account-budget-balances
                account)))


          (gnc:report-percent-done 10)


          ;; Existing liabilities must be negated.
          (set! existing-liabilities
            (get-assoc-account-balances-total-negated liability-account-initial-balances))

          ;; Budgeted liabilities are liability repayments (negative liabilities).
          (set! liability-repayments
            (gnc:get-assoc-account-balances-total liability-account-budget-balances))

          ;; New liabilities are then negated liability repayments.
          (set! new-liabilities
            (gnc:commodity-collector-get-negated liability-repayments))

	  ;; Total liabilities.
	  (set! liability-balance
            (gnc:collector+ existing-liabilities new-liabilities))

	  (gnc:report-percent-done 12)

          ;; Total existing retained earnings.
          ;; existing retained earnings = initial income - initial expenses
          (set! existing-retained-earnings
            (gnc:collector-
             (gnc:collector+
              (gnc:budget-accountlist-get-initial-balance budget income-accounts)
              (gnc:budget-accountlist-get-initial-balance budget expense-accounts))))

	  (gnc:report-percent-done 14)

          ;; Total new retained earnings.
          (set! new-retained-earnings
            (gnc:collector-
             (get-budget-accountlist-budget-balance budget income-accounts)
             (get-budget-accountlist-budget-balance budget expense-accounts)))

          ;; Total retained earnings.
          (set! retained-earnings
            (gnc:collector+ existing-retained-earnings new-retained-earnings))

	  (gnc:report-percent-done 16)

          ;; Total existing assets.
          (set! existing-assets
            (gnc:get-assoc-account-balances-total
              asset-account-initial-balances))

          ;; Total allocated assets.
          (set! allocated-assets
            (gnc:get-assoc-account-balances-total
              asset-account-budget-balances))

          ;; Total unallocated assets.
          ;; unallocated-assets =
          ;;  new-retained-earnings - allocated-assets - liability-repayments
          (set! unallocated-assets
            (gnc:collector- new-retained-earnings
                            allocated-assets
                            liability-repayments))

          ;; Total assets.
	  (set! asset-balance
            (gnc:collector+ existing-assets allocated-assets unallocated-assets))

	  (gnc:report-percent-done 18)

          ;; Calculate unrealized gains.
          (let* ((get-total-value-fn
                  (lambda (account)
                    (gnc:account-get-comm-value-at-date account date-t64 #f)))
                 (asset-basis
                  (gnc:accounts-get-comm-total-assets
                   asset-accounts get-total-value-fn))
                 (liability-basis
                  (gnc:collector-
                   (gnc:accounts-get-comm-total-assets
                    liability-accounts get-total-value-fn))))

            (set! unrealized-gain
              (gnc:collector-
               (gnc:collector- existing-assets asset-basis)
               (gnc:collector- existing-liabilities liability-basis))))

	  (gnc:report-percent-done 22)

          ;; Total existing equity; negative.
          (set! existing-equity
            (gnc:collector+
             (get-assoc-account-balances-total-negated equity-account-initial-balances)
             existing-retained-earnings
             unrealized-gain))

          ;; Total new equity; positive.
          (set! new-equity
            (gnc:collector+
             (gnc:get-assoc-account-balances-total equity-account-budget-balances)
             new-retained-earnings))

          ;; Total equity.
	  (set! equity-balance
            (gnc:collector+ existing-equity new-equity))

          ;; Total liability + equity.
	  (set! liability-plus-equity
            (gnc:collector+ liability-balance equity-balance))

	  (gnc:report-percent-done 30)
	  
          (gnc:html-document-set-title! 
            doc (string-append company-name " " report-title " " budget-name))

	  (set! table-env
		(list
		 (list 'start-date #f)
		 (list 'end-date #f)
		 (list 'display-tree-depth tree-depth)
		 (list 'depth-limit-behavior (if bottom-behavior
						 'flatten
						 'summarize))
		 (list 'report-commodity report-commodity)
		 (list 'exchange-fn exchange-fn)
		 (list 'parent-account-subtotal-mode parent-total-mode)
		 (list 'zero-balance-mode (if show-zb-accts?
					      'show-leaf-acct
					      'omit-leaf-acct))
		 (list 'account-label-mode (if use-links?
					       'anchor
					       'name))
		 )
		)
	  (set! params
		(list
		 (list 'parent-account-balance-mode parent-balance-mode)
		 (list 'zero-balance-display-mode (if omit-zb-bals?
						      'omit-balance
						      'show-balance))
		 (list 'multicommodity-mode (if show-fcur? 'table #f))
		 (list 'rule-mode use-rules?)
		  )
		)

          (let ((space (make-list tree-depth (gnc:make-html-table-cell/min-width 60))))
            (gnc:html-table-append-row! left-table space)
            (unless report-form?
              (gnc:html-table-append-row! right-table space)))

          (gnc:report-percent-done 80)
	  (if label-assets? (add-subtotal-line left-table (G_ "Assets") #f #f))
	  (set! asset-table
            (gnc:make-html-acct-table/env/accts
            (append table-env (list (list 'get-balance-fn asset-get-balance-fn)))
            asset-accounts))

	  (gnc:html-table-add-account-balances left-table asset-table params)
          (if total-assets?
            (begin
              (if new-existing?
                (begin
                  (add-subtotal-line
                    left-table (G_ "Existing Assets") #f existing-assets)
                  (add-subtotal-line
                    left-table (G_ "Allocated Assets") #f allocated-assets)))

              (if (not (gnc-commodity-collector-allzero? unallocated-assets))
                (add-subtotal-line
                  left-table (G_ "Unallocated Assets") #f unallocated-assets))

              (add-subtotal-line
                left-table (G_ "Total Assets") #f asset-balance)))
	  
	  (if report-form?
	      (add-rule left-table))
	  (if report-form?
	      (add-rule left-table))
	  
	  (gnc:report-percent-done 85)
	  (if label-liabilities?
	      (add-subtotal-line right-table (G_ "Liabilities") #f #f))
          (set! liability-table
            (gnc:make-html-acct-table/env/accts
              (append table-env
                (list (list 'get-balance-fn liability-get-balance-fn)))
              liability-accounts))
	  (gnc:html-table-add-account-balances
	   right-table liability-table params)
	  (if total-liabilities?
            (begin
              (if new-existing?
                (begin
                  (add-subtotal-line
                    right-table
                    (G_ "Existing Liabilities")
                    #f
                    existing-liabilities)

                  (add-subtotal-line
                    right-table (G_ "New Liabilities") #f new-liabilities)))

	      (add-subtotal-line
                right-table (G_ "Total Liabilities") #f liability-balance)))
	  
	  (add-rule right-table)
	  
	  (gnc:report-percent-done 88)
	  (if label-equity?
	      (add-subtotal-line
	       right-table (G_ "Equity") #f #f))
	  (set! equity-table
		(gnc:make-html-acct-table/env/accts
                  (append table-env
                    (list (list 'get-balance-fn equity-get-balance-fn)))
                 equity-accounts))
	  (gnc:html-table-add-account-balances
	   right-table equity-table params)

          ;; we omit retianed earnings from the balance report, if zero, since
          ;; they are not present on normal balance sheets
          (if (not (gnc-commodity-collector-allzero? retained-earnings))
            (if new-existing?
              (begin
                (add-subtotal-line
                  right-table
                  (G_ "Existing Retained Earnings")
                  (G_ "Existing Retained Losses")
                  existing-retained-earnings)

                (add-subtotal-line
                  right-table
                  (G_ "New Retained Earnings")
                  (G_ "New Retained Losses")
                  new-retained-earnings)))

              (add-subtotal-line
                right-table
                (G_ "Total Retained Earnings")
                (G_ "Total Retained Losses")
                retained-earnings))


          (if (not (gnc-commodity-collector-allzero? unrealized-gain))
            (add-subtotal-line right-table
              (G_ "Unrealized Gains")
              (G_ "Unrealized Losses")
              unrealized-gain))


	  (if total-equity?
            (begin
              (if new-existing?
                (begin
                  (add-subtotal-line
                    right-table (G_ "Existing Equity") #f existing-equity)

                  (add-subtotal-line
                    right-table (G_ "New Equity") #f new-equity)))

	      (add-subtotal-line
                right-table (G_ "Total Equity") #f equity-balance)))
	  
	  (add-rule right-table)
	  
          (add-subtotal-line
            right-table
            (gnc:html-string-sanitize (G_ "Total Liabilities & Equity"))
            #f
            liability-plus-equity)
	  
	  (gnc:html-document-add-object!
	   doc
	   (if report-form?
	       left-table
	       (let* ((build-table (gnc:make-html-table))
		      )
		 (gnc:html-table-append-row!
		  build-table
		  (list
		   (gnc:make-html-table-cell left-table)
		   (gnc:make-html-table-cell right-table)
		   )
		  )
		 (gnc:html-table-set-style!
		  build-table "td"
		  'attribute '("align" "left")
		  'attribute '("valign" "top"))
		 build-table
		 )
	       )
	   )
	  
          ;; add currency information if requested
	  (gnc:report-percent-done 90)
          (if show-rates?
              (gnc:html-document-add-object! 
               doc ;;(gnc:html-markup-p)
               (gnc:html-make-rates-table report-commodity price-fn accounts)))
	  (gnc:report-percent-done 100)))))
    
    (gnc:report-finished)
    
    doc))

(gnc:define-report 
 'version 1
 'name reportname
 'report-guid "ecc35ea9dbfa4e20ba389fc85d59cb69"
 'menu-path (list gnc:menuname-budget)
 'options-generator budget-balance-sheet-options-generator
 'renderer budget-balance-sheet-renderer)
