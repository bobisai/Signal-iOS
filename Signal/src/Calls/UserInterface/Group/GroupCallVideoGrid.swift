//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalRingRTC

class GroupCallVideoGrid: UICollectionView {
    let layout: GroupCallVideoGridLayout
    let call: SignalCall
    init(call: SignalCall) {
        self.call = call
        self.layout = GroupCallVideoGridLayout()

        super.init(frame: .zero, collectionViewLayout: layout)

        call.addObserverAndSyncState(observer: self)
        layout.delegate = self

        register(GroupCallVideoGridCell.self, forCellWithReuseIdentifier: GroupCallVideoGridCell.reuseIdentifier)
        dataSource = self
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { call.removeObserver(self) }
}

extension GroupCallVideoGrid: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? GroupCallVideoGridCell else { return }
        cell.cleanupVideoViews()
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? GroupCallVideoGridCell else { return }
        guard let remoteDevice = gridRemoteDeviceStates[safe: indexPath.row] else {
            return owsFailDebug("missing member address")
        }
        cell.configureRemoteVideo(device: remoteDevice)
    }
}

extension GroupCallVideoGrid: UICollectionViewDataSource {
    var gridRemoteDeviceStates: [RemoteDeviceState] {
        let remoteDeviceStates = call.groupCall.remoteDeviceStates.sortedBySpeakerTime
        return Array(remoteDeviceStates[0..<min(maxItems, call.groupCall.remoteDeviceStates.count)]).sortedByAddedTime
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return gridRemoteDeviceStates.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GroupCallVideoGridCell.reuseIdentifier,
            for: indexPath
        ) as! GroupCallVideoGridCell

        guard let remoteDevice = gridRemoteDeviceStates[safe: indexPath.row] else {
            owsFailDebug("missing member address")
            return cell
        }

        cell.configure(call: call, device: remoteDevice)

        return cell
    }
}

extension GroupCallVideoGrid: CallObserver {
    func groupCallLocalDeviceStateChanged(_ call: SignalCall) {}

    func groupCallRemoteDeviceStatesChanged(_ call: SignalCall) {
        AssertIsOnMainThread()
        owsAssertDebug(call.isGroupCall)

        reloadData()
    }

    func groupCallPeekChanged(_ call: SignalCall) {
        AssertIsOnMainThread()
        owsAssertDebug(call.isGroupCall)

        reloadData()
    }
}

extension GroupCallVideoGrid: GroupCallVideoGridLayoutDelegate {
    var maxColumns: Int {
        if CurrentAppContext().frame.width > 1080 {
            return 4
        } else if CurrentAppContext().frame.width > 768 {
            return 3
        } else {
            return 2
        }
    }

    var maxRows: Int {
        if CurrentAppContext().frame.height > 1024 {
            return 4
        } else {
            return 3
        }
    }

    var maxItems: Int { maxColumns * maxRows }

    func deviceState(for index: Int) -> RemoteDeviceState? {
        return gridRemoteDeviceStates[safe: index]
    }
}

class GroupCallVideoGridCell: UICollectionViewCell {
    static let reuseIdentifier = "GroupCallVideoGridCell"
    private let memberView = GroupCallRemoteMemberView(mode: .videoGrid)

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(memberView)
        memberView.autoPinEdgesToSuperviewEdges()

        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
    }

    func configure(call: SignalCall, device: RemoteDeviceState) {
        memberView.configure(call: call, device: device)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cleanupVideoViews() {
        memberView.cleanupVideoViews()
    }

    func configureRemoteVideo(device: RemoteDeviceState) {
        memberView.configureRemoteVideo(device: device)
    }
}

extension Sequence where Element: RemoteDeviceState {
    /// The first person to join the call is the first item in the list.
    var sortedByAddedTime: [RemoteDeviceState] {
        return sorted { lhs, rhs in
            if lhs.addedTime == rhs.addedTime { return lhs.demuxId < rhs.demuxId }
            return lhs.addedTime < rhs.addedTime
        }
    }

    /// The most recent speaker is the first item in the list.
    var sortedBySpeakerTime: [RemoteDeviceState] {
        return sorted { lhs, rhs in
            if lhs.speakerTime == rhs.speakerTime { return lhs.demuxId < rhs.demuxId }
            return lhs.speakerTime > rhs.speakerTime
        }
    }
}

extension Dictionary where Value: RemoteDeviceState {
    /// The first person to join the call is the first item in the list.
    var sortedByAddedTime: [RemoteDeviceState] {
        return values.sortedByAddedTime
    }

    /// The most recent speaker is the first item in the list.
    var sortedBySpeakerTime: [RemoteDeviceState] {
        return values.sortedBySpeakerTime
    }
}