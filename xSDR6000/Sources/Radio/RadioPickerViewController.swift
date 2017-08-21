
//  RadioPickerViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/21/15.

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - RadioPickerDelegate definition
// --------------------------------------------------------------------------------

protocol RadioPickerDelegate {
    
    var activeRadio: RadioParameters? {get}
    
    func closeRadioPicker()
    func openRadio(_ radio: RadioParameters?) -> Bool
    func closeRadio()
//    func updateAvailableRadios()
}

// --------------------------------------------------------------------------------
// MARK: - Radio Picker View Controller class implementation
// --------------------------------------------------------------------------------

final class RadioPickerViewController : NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet fileprivate var _radioTableView: NSTableView!         // table of Radios
    @IBOutlet fileprivate var _selectButton: NSButton!              // Connect / Disconnect
    @IBOutlet fileprivate var _defaultButton: NSButton!             // Set as default
    
    fileprivate var _availableRadios = [ RadioParameters]()         // Array of of Radio Parameters
    fileprivate var _notifications = [NSObjectProtocol]()           // Notification observers
    fileprivate var _selectedRadio: RadioParameters?                // Radio in selected row
//    fileprivate var _hasDefaultRadio = false
//    fileprivate var _defaultRadio: RadioParameters?

    fileprivate var _delegate : RadioPickerDelegate {               // Delegate
         return representedObject as! RadioPickerDelegate }

    fileprivate var _radioFactory = RadioFactory()

    // constants
    fileprivate let kModule = "RadioPickerViewController"           // Module Name reported in log messages
    fileprivate let kColumnIdentifierDefaultRadio = "defaultRadio"  // column identifier
    fileprivate let kConnectTitle = "Connect"
    fileprivate let kDisconnectTitle = "Disconnect"
    fileprivate let kSetAsDefault = "Set as Default"
    fileprivate let kClearDefault = "Clear Default"
    fileprivate let kDefaultFlag = "YES"
    fileprivate let kMaxTries = 3
    
    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        
        // allow the User to double-click the desired Radio
        _radioTableView.doubleAction = #selector(RadioPickerViewController.selectButton(_:))
        
        _selectButton.title = kConnectTitle
        addNotifications()
        
//        // see if there is a valid default Radio
//        _defaultRadio = RadioParameters( Defaults[.defaultsDictionary] )
//        if _defaultRadio?.ipAddress != "" && _defaultRadio?.port != 0 { _hasDefaultRadio = true }
        
        _radioFactory.updateAvailableRadios()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
        
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    @IBAction func quit(_ sender: AnyObject) {
        
        // close this controller
        dismissViewController(self)

        NSApp.terminate(self)
    }
    /// Respond to the Default button
    ///
    /// - Parameter sender: the button
    ///
    @IBAction func defaultButton(_ sender: NSButton) {

        // save the selection
        let selectedRow = _radioTableView.selectedRow
        
        // Clear / Set the Default
        if sender.title == kSetAsDefault {
            
            Defaults[.defaultsDictionary] = _availableRadios[selectedRow].dictFromParams()
        
        } else {
            
            Defaults[.defaultsDictionary] = RadioParameters().dictFromParams()
        }
        
        // to display the Default status
        _radioTableView.reloadData()

        // restore the selection
        _radioTableView.selectRowIndexes(IndexSet(integersIn: selectedRow..<selectedRow+1), byExtendingSelection: true)
        
    }
    /// Respond to the Close button
    ///
    /// - Parameter sender: the button
    ///
    @IBAction func closeButton(_ sender: AnyObject) {
        
        // unsubscribe from Notifications
        NC.deleteObserver(self, of: .radiosAvailable, object: nil)
        
        // close this view & controller
        _delegate.closeRadioPicker()
    }
    /// Respond to the Select button
    ///
    /// - Parameter _: the button
    ///
    @IBAction func selectButton( _: AnyObject ) {
        
        openClose()
    }
    /// Respond to a double-clicked Table row
    ///
    /// - Parameter _: the row clicked
    ///
    func doubleClick(_: AnyObject) {
        
        openClose()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Open or Close the selected Radio
    ///
    /// - Parameter open: Open/Close
    ///
    fileprivate func openClose() {
        
        if _selectButton.title == kConnectTitle {
            // RadioPicker sheet will close & Radio will be opened
            
            // tell the delegate to connect to the selected Radio
            let _ = _delegate.openRadio(_selectedRadio)
                
        } else {
            // RadioPicker sheet will remain open & Radio will be disconnected
            
            // tell the delegate to disconnect
            _delegate.closeRadio()
            _selectButton.title = kConnectTitle
        }
    }
    
    /// Reload the Radio table
    ///
    fileprivate func reload() {
        
        _radioTableView.reloadData()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subscriptions to Notifications
    ///
    fileprivate func addNotifications() {
        
        // Available Radios changed
        NC.makeObserver(self, with: #selector(radiosAvailable(_:)), of: .radiosAvailable, object: nil)
    }
    /// Process .radiosAvailable Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func radiosAvailable(_ note: Notification) {
        
        DispatchQueue.main.async {
            
            // receive the updated list of Radios
            self._availableRadios = (note.object as! [ RadioParameters ])
            
            // reload the table of Radios
            self.reload()
            
            // see if there is a valid default Radio
            let defaultRadio = RadioParameters( Defaults[.defaultsDictionary] )
            if defaultRadio.ipAddress != "" && defaultRadio.port != 0 {
                
                // has the default Radio been found?
                for (i, foundRadio) in self._availableRadios.enumerated() where foundRadio == defaultRadio {
                    
                    // YES, Save it in case something changed
                    Defaults[.defaultsDictionary] = foundRadio.dictFromParams()
                    
                    // select it in the TableView
                    self._radioTableView.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: true)
                    
                    // is a Radio open?
                    if self._delegate.activeRadio == nil {
                        
                        // NO, open the default radio
                        self.openClose()
                    }
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - NSTableView DataSource methods
    
    /// Tableview numberOfRows delegate method
    ///
    /// - Parameter aTableView: the Tableview
    /// - Returns: number of rows
    ///
    func numberOfRows(in aTableView: NSTableView) -> Int {
        
        // get the number of rows
        return _availableRadios.count
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - NSTableView Delegate methods
    
    /// Tableview view delegate method
    ///
    /// - Parameters:
    ///   - tableView: the Tableview
    ///   - tableColumn: a Tablecolumn
    ///   - row: the row number
    /// - Returns: an NSView
    ///
    func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // get a view for the cell
        let view = tableView.make(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
        
        // what field?
        if tableColumn!.identifier == kColumnIdentifierDefaultRadio {
            
            // is this row the default?
            let defaultRadio = RadioParameters( Defaults[.defaultsDictionary] )
            view.textField!.stringValue = (defaultRadio == _availableRadios[row] ? kDefaultFlag : "")
            
        } else {
            
            // all other fields, set the stringValue of the cell's text field to the appropriate field
            view.textField!.stringValue = _availableRadios[row].valueForName(tableColumn!.identifier)!
        }
        return view
    }
    
    /// Tableview selection change delegate method
    ///
    /// - Parameter notification: notification object
    ///
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        // A row must be selected to enable the buttons
        _selectButton.isEnabled = (_radioTableView.selectedRow >= 0)
        _defaultButton.isEnabled = (_radioTableView.selectedRow >= 0)
        
        if _radioTableView.selectedRow >= 0 {
            
            // a row is selected
            _selectedRadio = _availableRadios[_radioTableView.selectedRow]
            
            // set "default button" title appropriately
            let defaultRadio = RadioParameters( Defaults[.defaultsDictionary] )
            _defaultButton.title = (defaultRadio == _availableRadios[_radioTableView.selectedRow] ? kClearDefault : kSetAsDefault)
            
            // set the "select button" title appropriately
            let isActive = _delegate.activeRadio == _availableRadios[_radioTableView.selectedRow]
            _selectButton.title = (isActive ? kDisconnectTitle : kConnectTitle)
            
        } else {
            
            // no row is selected, set the button titles
            _defaultButton.title = kSetAsDefault
            _selectButton.title = kConnectTitle
        }
    }
}
