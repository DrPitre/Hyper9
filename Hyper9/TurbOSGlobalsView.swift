//
//  TurbOSGlobalsView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 2/22/25.
//

import SwiftUI

struct TurbOSGlobalsView: View {
    @EnvironmentObject var model: Turbo9ViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                memoryMapSection
                vectorsSection
                schedulingSection
                timeSection
                ioSection
                bootSection
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections

    private var memoryMapSection: some View {
        GlobalsSection("Memory Map") {
            cells {
                hex16("D.FMBM Start", model.turbo9.D_FMBM_Start)
                hex16("D.FMBM End",   model.turbo9.D_FMBM_End)
                hex16("D.MLIM",       model.turbo9.D_MLIM)
                hex16("D.ModDir Start", model.turbo9.D_ModDir_Start)
                hex16("D.ModDir End",   model.turbo9.D_ModDir_End)
            }
        }
    }

    private var vectorsSection: some View {
        GlobalsSection("Interrupt & SWI Vectors") {
            cells {
                hex16("D.Init",    model.turbo9.D_Init)
                hex16("D.NMI",     model.turbo9.D_NMI)
                hex16("D.IRQ",     model.turbo9.D_IRQ)
                hex16("D.FIRQ",    model.turbo9.D_FIRQ)
                hex16("D.SWI",     model.turbo9.D_SWI)
                hex16("D.SWI2",    model.turbo9.D_SWI2)
                hex16("D.SWI3",    model.turbo9.D_SWI3)
                hex16("D.Poll",    model.turbo9.D_Poll)
                hex16("D.SvcIRQ",  model.turbo9.D_SvcIRQ)
                hex16("D.UsrIRQ",  model.turbo9.D_UsrIRQ)
                hex16("D.SysIRQ",  model.turbo9.D_SysIRQ)
                hex16("D.UsrSvc",  model.turbo9.D_UsrSvc)
                hex16("D.SysSvc",  model.turbo9.D_SysSvc)
                hex16("D.UsrDis",  model.turbo9.D_UsrDis)
                hex16("D.SysDis",  model.turbo9.D_SysDis)
            }
        }
    }

    private var schedulingSection: some View {
        GlobalsSection("Process Scheduling") {
            cells {
                hex8 ("D.Slice",   model.turbo9.D_Slice)
                hex16("D.Proc",    model.turbo9.D_Proc)
                hex16("D.PrcDBT",  model.turbo9.D_PrcDBT)
                hex16("D.AProcQ",  model.turbo9.D_AProcQ)
                hex16("D.WProcQ",  model.turbo9.D_WProcQ)
                hex16("D.SProcQ",  model.turbo9.D_SProcQ)
            }
        }
    }

    private var timeSection: some View {
        GlobalsSection("Date & Clock") {
            cells {
                hex8 ("D.Year",       model.turbo9.D_Year)
                hex8 ("D.Month",      model.turbo9.D_Month)
                hex8 ("D.Day",        model.turbo9.D_Day)
                hex8 ("D.Hour",       model.turbo9.D_Hour)
                hex8 ("D.Min",        model.turbo9.D_Min)
                hex8 ("D.Sec",        model.turbo9.D_Sec)
                hex16("D.Ticks Hi",   model.turbo9.D_Ticks_High)
                hex16("D.Ticks Lo",   model.turbo9.D_Ticks_Low)
                hex8 ("D.Tick",       model.turbo9.D_Tick)
                hex8 ("D.TSec",       model.turbo9.D_TSec)
                hex8 ("D.TSlice",     model.turbo9.D_TSlice)
                hex16("D.Clock",      model.turbo9.D_Clock)
            }
        }
    }

    private var ioSection: some View {
        GlobalsSection("I/O & Devices") {
            cells {
                hex16("D.IOML",      model.turbo9.D_IOML)
                hex16("D.IOMH",      model.turbo9.D_IOMH)
                hex16("D.DevTbl",    model.turbo9.D_DevTbl)
                hex16("D.PolTbl",    model.turbo9.D_PolTbl)
                hex16("D.PthDBT",    model.turbo9.D_PthDBT)
                hex16("D.BTLO",      model.turbo9.D_BTLO)
                hex16("D.BTHI",      model.turbo9.D_BTHI)
                hex16("D.URtoSs",    model.turbo9.D_UrToSs)
                hex16("D.VIRQTable", model.turbo9.D_VIRQTable)
            }
        }
    }

    private var bootSection: some View {
        GlobalsSection("Boot & Misc") {
            cells {
                hex8 ("D.Boot", model.turbo9.D_Boot)
                hex8 ("D.CRC",  model.turbo9.D_CRC)
            }
        }
    }

    // MARK: - Helpers

    private func hex16(_ label: String, _ value: UInt16) -> GlobalsCell {
        GlobalsCell(label: label, value: String(format: "$%04X", value))
    }

    private func hex8(_ label: String, _ value: UInt8) -> GlobalsCell {
        GlobalsCell(label: label, value: String(format: "$%02X", value))
    }

    @ViewBuilder
    private func cells(@GlobalsCellBuilder _ build: () -> [GlobalsCell]) -> some View {
        let items = build()
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 14, alignment: .leading)],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(items) { $0 }
        }
    }
}

// MARK: - Result builder so the call sites stay tidy

@resultBuilder
private enum GlobalsCellBuilder {
    static func buildBlock(_ components: GlobalsCell...) -> [GlobalsCell] { components }
}

// MARK: - Cell + section primitives

private struct GlobalsCell: View, Identifiable {
    let id = UUID()
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
                )
                .textSelection(.enabled)
        }
    }
}

private struct GlobalsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            content
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
                )
        }
    }
}

#Preview {
    TurbOSGlobalsView()
        .environmentObject(Turbo9ViewModel())
}
