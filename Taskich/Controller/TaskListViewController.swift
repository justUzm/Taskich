import UIKit

protocol TaskListViewControllerDelegate: AnyObject {
    func didTapMenuButton()
}

class TaskListViewController: UITableViewController,  UITableViewDragDelegate, UITableViewDropDelegate {
    
    var tasks = [Task]()
    var isEditingMode = false
    var selectedRows = Set<Int>()
    var editModeToolbar = EditModeToolbarView()
    weak var delegate: TaskListViewControllerDelegate?
    var editModeToolbarBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        setupNavigationBar()
        setupEditModeToolbar()
        updateData()
    }
    
    // MARK: - Setup methods
    private func setupTableView() {
        tableView.register(TaskCell.self, forCellReuseIdentifier: "TaskCell")
        tableView.separatorStyle = .none
        tableView.dragInteractionEnabled = true
        tableView.dragDelegate = self
        tableView.dropDelegate = self
    }
    
    private func setupNavigationBar() {
        title = "Taskich"
        
        if isEditingMode {
            let cancelTaskButton = UIBarButtonItem(image: UIImage(systemName: "arrow.left"),
                                                   style: .plain,
                                                   target: self,
                                                   action: #selector(cancelEditing))
            cancelTaskButton.tintColor = .black
            navigationItem.rightBarButtonItem = cancelTaskButton
        } else {
            let addTaskButton = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                                style: .plain,
                                                target: self,
                                                action: #selector(addTask))
            addTaskButton.tintColor = .black
            navigationItem.rightBarButtonItem = addTaskButton
        }
        
        let menuButton = UIBarButtonItem(image: UIImage(systemName: "list.dash"),
                                                           style: .done,
                                                           target: self,
                                                           action: #selector(didTapMenuButton))
        menuButton.tintColor = .black
        navigationItem.leftBarButtonItem = menuButton
    }
    
    private func setupEditModeToolbar() {
        view.addSubview(editModeToolbar)
        editModeToolbar.isHidden = true
        editModeToolbarBottomConstraint = editModeToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 100)

        
        editModeToolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editModeToolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editModeToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            editModeToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            editModeToolbarBottomConstraint
        ])
        
        editModeToolbar.deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        editModeToolbar.dateButton.addTarget(self, action: #selector(dateButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Core Data
    func updateData() {
        tasks = StorageManager.shared.fetchCurrentTasks()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Config reusable cell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath) as? TaskCell else {
            fatalError()
        }
        cell.delegate = self
        
        // Swipe gesture
        let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(leftSwipeGestureRecognizer(_:)))
        swipeLeftGesture.direction = .left
        cell.addGestureRecognizer(swipeLeftGesture)
        
        // TaskCell.configure
        cell.configure(task: tasks[indexPath.row])
        
        // Design for editingMode
        if selectedRows.contains(indexPath.row) {
            cell.layer.cornerRadius = 8
            cell.selectedBackground.isHidden = false
        } else {
            cell.layer.cornerRadius = 0
            cell.selectedBackground.isHidden = true
        }
        
        return cell
    }
    
    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditingMode {
            if selectedRows.contains(indexPath.row) {
                selectedRows.remove(indexPath.row)
            } else {
                selectedRows.insert(indexPath.row)
            }
            
            tableView.reloadRows(at: [indexPath], with: .none)
            
            if selectedRows.isEmpty {
                cancelEditing()
            }
        } else {
            presentTask(at: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if isEditingMode {
            cancelEditing()
        }
        
        let movedTask = tasks.remove(at: sourceIndexPath.row)
        tasks.insert(movedTask, at: destinationIndexPath.row)
    }
    
    // MARK: - Drag&Drop protocol
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let task = tasks[indexPath.row]
        let itemProvider = NSItemProvider(object: task.text! as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        
        editModeToolbar.isHidden = true
        
        return [dragItem]
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        let destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            let section = tableView.numberOfSections - 1
            let row = tableView.numberOfRows(inSection: section)
            destinationIndexPath = IndexPath(row: row, section: section)
        }
        
        coordinator.session.loadObjects(ofClass: NSString.self) { items in
            guard let taskLabels = items as? [String] else { return }
            let taskLabel = taskLabels.first
            if let index = self.tasks.firstIndex(where: { $0.text == taskLabel }) {
                let movedTask = self.tasks.remove(at: index)
                self.tasks.insert(movedTask, at: destinationIndexPath.row)
                tableView.reloadData()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let previewParameters = UIDragPreviewParameters()
        
        if let cell = tableView.cellForRow(at: indexPath) {
            let bezierPath = UIBezierPath(roundedRect:cell.bounds.insetBy(dx: 8, dy: 0),
                                          cornerRadius: 8.0)
            
            previewParameters.visiblePath = bezierPath
        }
        
        return previewParameters
    }
    
    // MARK: - Present Methods
    @objc private func addTask() {
        let addFormController = AddFormViewController()
        addFormController.modalPresentationStyle = .overCurrentContext
        present(addFormController, animated: false)
        
        addFormController.onAddButtonTapped = { taskText, date in
            if !taskText.isEmpty {
                StorageManager.shared.createTask(text: taskText, date: date)
                self.updateData()
            }
        }
    }
    
    private func presentTask(at indexPath: IndexPath) {
        let presenterViewController = TaskPresenterViewController()
        presenterViewController.modalPresentationStyle = .formSheet
        
        presenterViewController.taskText = tasks[indexPath.row].text
        presenterViewController.taskDate = tasks[indexPath.row].date
        presenterViewController.taskReminder = tasks[indexPath.row].reminder
        
        let taskID = tasks[indexPath.row].id
        let tempReminder = tasks[indexPath.row].reminder
        
        presenterViewController.onTaskTextUpdate = { text, date, reminder in
            StorageManager.shared.updateTask(with: taskID, newText: text, newDate: date, newReminder: reminder)
            self.updateData()
            self.configureNotification(previousReminder: tempReminder, task: self.tasks[indexPath.row])
        }
        
        present(presenterViewController, animated: true)
    }
    
    private func configureNotification(previousReminder: Date?, task: Task) {
        if previousReminder == nil && task.reminder != nil {
            NotificationManager.shared.createNotification(for: task)
        } else if previousReminder != nil && task.reminder == nil {
            NotificationManager.shared.deleteNotification(with: task.id)
        } else {
            NotificationManager.shared.updateNotification(in: task)
        }
    }
    
    @objc private func didTapMenuButton() {
        delegate?.didTapMenuButton()
    }
    
    // MARK: - Other Methods
    private func configureNotification() {
        
    }
    
    @objc private func leftSwipeGestureRecognizer(_ gesture: UISwipeGestureRecognizer) {
        
        guard let indexPath = tableView.indexPathForRow(at: gesture.location(in: tableView)),
              let cell = tableView.cellForRow(at: indexPath)
        else {
            return
        }
        
        isEditingMode = true
        showEditModeToolbar()
        setupNavigationBar()
        
        if selectedRows.contains(indexPath.row) {
            selectedRows.remove(indexPath.row)
        } else {
            selectedRows.insert(indexPath.row)
        }
        
        leftSwipeGestureAnimation(for: cell, at: indexPath)
    }
    
    @objc private func cancelEditing() {
        isEditingMode = false
        hideEditModeToolbar()
        selectedRows.removeAll()
        setupNavigationBar()
        tableView.reloadData()
    }
    
    private func leftSwipeGestureAnimation(for cell: UITableViewCell, at indexPath: IndexPath) {
        UIView.animate(withDuration: 0.1) {
            cell.transform = CGAffineTransform(translationX: -10, y: 0)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                cell.transform = CGAffineTransform.identity
            } completion: { _ in
                if self.selectedRows.isEmpty {
                    self.cancelEditing()
                } else {
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
        }
    }
    
    private func deleteSelectedRows() {
        let sortedSelectedRows = selectedRows.sorted(by: >)
        var indexPathsToDelete: [IndexPath] = []
        
        for indexPathRow in sortedSelectedRows {
            let deletedTask = tasks.remove(at: indexPathRow)
            StorageManager.shared.moveToTrash(task: deletedTask.id)
            indexPathsToDelete.append(IndexPath(row: indexPathRow, section: 0))
            
            if let navigationController = parent as? UINavigationController,
               let containerVC = navigationController.parent as? ContainerViewController {
                containerVC.updateTrash()
            }
            
            self.updateData()
        }
        
        tableView.beginUpdates()
        tableView.deleteRows(at: indexPathsToDelete, with: .fade)
        tableView.endUpdates()
        
        selectedRows.removeAll()
        tableView.reloadData()
    }

    
    @objc private func deleteButtonTapped() {
        deleteSelectedRows()
        cancelEditing()
    }
    
    private func changeDateSelectedRows(with date: Date) {
        let sortedSelectedRows = selectedRows.sorted(by: >)
        for indexPathRow in sortedSelectedRows {
            let taskToChange = tasks[indexPathRow]
            StorageManager.shared.updateTask(with: taskToChange.id, newText: nil, newDate: date, newReminder: nil)
            self.updateData()
        }
        cancelEditing()
    }

    
    @objc private func dateButtonTapped() {
        let datePickerViewController = DatePickerViewController()
        datePickerViewController.modalPresentationStyle = .overFullScreen
        datePickerViewController.appear(sender: self)
        datePickerViewController.onDateSelected = { [weak self] selectedDate in
            self?.changeDateSelectedRows(with: selectedDate)
        }
    }
    
    
    private func showEditModeToolbar() {
        editModeToolbar.isHidden = false
        editModeToolbarBottomConstraint.constant = -24
        UIView.animate(withDuration: 0.15) {
            self.view.layoutIfNeeded()
        }

    }

    private func hideEditModeToolbar() {
        editModeToolbarBottomConstraint.constant = 100
        UIView.animate(withDuration: 0.15) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.editModeToolbar.isHidden = true
        }
    }
}

extension TaskListViewController: TaskCellDelegate {
    func archived(_ cell: TaskCell, didCompleteTask task: Task) {
        if let index = tasks.firstIndex(where: { $0.text == task.text && $0.date == task.date }) {
            let archivedTask = tasks[index]
            StorageManager.shared.moveToArchive(task: archivedTask.id)
            self.updateData()
            if let navigationController = parent as? UINavigationController,
               let containerVC = navigationController.parent as? ContainerViewController {
                containerVC.updateArchive()
            }
            tableView.beginUpdates()
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .right)
            tableView.endUpdates()
        }
    }
    
    func unarchived(_ cell: TaskCell, didUnarchivedTask task: Task) {
        //
    }
}





