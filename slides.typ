#let section = state("section", none)
#let subslide = counter("subslide")
#let logical-slide = counter("logical-slide")
#let repetitions = counter("repetitions")
#let cover-mode = state("cover-mode", "invisible")
#let pause-counter = counter("pause-counter")
#let global-theme = state("global-theme", none)

#let cover-mode-invisible = cover-mode.update("invisible")
#let cover-mode-transparent = cover-mode.update("transparent")
#let new-section(name) = section.update(name)

#let slides-default-theme(color: teal) = data => {
    let title-slide = {
        align(center + horizon)[
            #block(
                stroke: ( y: 1mm + color ),
                inset: 1em,
                breakable: false,
                [
                    #text(1.3em)[*#data.title*] \
                    #{
                        if data.subtitle != none {
                            parbreak()
                            text(.9em)[#data.subtitle]
                        }
                    }
                ]
            )
            #set text(size: .8em)
            #grid(
                columns: (1fr,) * calc.min(data.authors.len(), 3),
                column-gutter: 1em,
                row-gutter: 1em,
                ..data.authors
            )
            #v(1em)
            #data.date
        ]
    }

    let default(slide-info, body) = {
        let decoration(position, body) = {
            let border = 1mm + color
            let strokes = (
                header: ( bottom: border ),
                footer: ( top: border )
            )
            block(
                stroke: strokes.at(position),
                width: 100%,
                inset: .3em,
                text(.5em, body)
            )
        }


        // header
        decoration("header", section.display())

        if "title" in slide-info {
            block(
                width: 100%, inset: (x: 2em), breakable: false,
                outset: 0em,
                heading(level: 1, slide-info.title)
            )
        }
        
        v(1fr)
        block(
            width: 100%, inset: (x: 2em), breakable: false, outset: 0em,
            body
        )
        v(2fr)

        // footer
        decoration("footer")[
            #data.short-authors #h(10fr)
            #data.short-title #h(1fr)
            #data.date #h(10fr)
            #logical-slide.display()
        ]
    }

    let wake-up(slide-info, body) = {
        block(
            width: 100%, height: 100%, inset: 2em, breakable: false, outset: 0em,
            fill: color,
            text(size: 1.5em, fill: white, {v(1fr); body; v(1fr)})
        )
    }

    (
        title-slide: title-slide,
        variants: ( "default": default, "wake up": wake-up, ),
    )
}

#let _slides-cover(body) = {
    locate( loc => {
        let mode = cover-mode.at(loc)
        if mode == "invisible" {
            hide(body)
        } else if mode == "transparent" {
            text(gray.lighten(50%), body)
        } else {
            panic("Illegal cover mode: " + mode)
        }
    })
}

#let _parse-subslide-indices(s) = {
    let parts = s.split(",").map(p => p.trim())
    let parse-part(part) = {
        let match-until = part.match(regex("^-([[:digit:]]+)$"))
        let match-beginning = part.match(regex("^([[:digit:]]+)-$"))
        let match-range = part.match(regex("^([[:digit:]]+)-([[:digit:]]+)$"))
        let match-single = part.match(regex("^([[:digit:]]+)$"))
        if match-until != none {
            let parsed = int(match-until.captures.first())
            // assert(parsed > 0, "parsed idx is non-positive")
            ( until: parsed )
        } else if match-beginning != none {
            let parsed = int(match-beginning.captures.first())
            // assert(parsed > 0, "parsed idx is non-positive")
            ( beginning: parsed )
        } else if match-range != none {
            let parsed-first = int(match-range.captures.first())
            let parsed-last = int(match-range.captures.last())
            // assert(parsed-first > 0, "parsed idx is non-positive")
            // assert(parsed-last > 0, "parsed idx is non-positive")
            ( beginning: parsed-first, until: parsed-last )
        } else if match-single != none {
            let parsed = int(match-single.captures.first())
            // assert(parsed > 0, "parsed idx is non-positive")
            parsed
        } else {
            panic("failed to parse visible slide idx:" + part)
        }
    }
    parts.map(parse-part)
}

#let _check-visible(idx, visible-subslides) = {
    if type(visible-subslides) == "integer" {
        idx == visible-subslides
    } else if type(visible-subslides) == "array" {
        visible-subslides.any(s => _check-visible(idx, s))
    } else if type(visible-subslides) == "string" {
        let parts = _parse-subslide-indices(visible-subslides)
        _check-visible(idx, parts)
    } else if type(visible-subslides) == "dictionary" {
        let lower-okay = if "beginning" in visible-subslides {
            visible-subslides.beginning <= idx
        } else {
            true
        }

        let upper-okay = if "until" in visible-subslides {
            visible-subslides.until >= idx
        } else {
            true
        }

        lower-okay and upper-okay
    } else {
        panic("you may only provide a single integer, an array of integers, or a string")
    }
}

#let _last-required-subslide(visible-subslides) = {
    if type(visible-subslides) == "integer" {
        visible-subslides
    } else if type(visible-subslides) == "array" {
        calc.max(..visible-subslides.map(s => _last-required-subslide(s)))
    } else if type(visible-subslides) == "string" {
        let parts = _parse-subslide-indices(visible-subslides)
        _last-required-subslide(parts)
    } else if type(visible-subslides) == "dictionary" {
        let last = 0
        if "beginning" in visible-subslides {
            last = calc.max(last, visible-subslides.beginning)
        }
        if "until" in visible-subslides {
            last = calc.max(last, visible-subslides.until)
        }
        last
    } else {
        panic("you may only provide a single integer, an array of integers, or a string")
    }
}

#let only(visible-subslides, reserve-space: false, body) = {
    repetitions.update(rep => calc.max(rep, _last-required-subslide(visible-subslides)))
    locate( loc => {
        if _check-visible(subslide.at(loc).first(), visible-subslides) {
            body
        } else if reserve-space {
            _slides-cover(body)
        }
    })
}

#let uncover(visible-subslides, body) = {
    only(visible-subslides, reserve-space: true, body)
}

#let one-by-one(start: 1, ..children) = {
    repetitions.update(rep => calc.max(rep, start + children.pos().len() - 1))
    for (idx, child) in children.pos().enumerate() {
        uncover((beginning: start + idx), child)
    }
}

#let alternatives(start: 1, position: bottom + left, ..children) = {
    repetitions.update(rep => calc.max(rep, start + children.pos().len() - 1))
    style(styles => {
        let sizes = children.pos().map(c => measure(c, styles))
        let max-width = calc.max(..sizes.map(sz => sz.width))
        let max-height = calc.max(..sizes.map(sz => sz.height))
        for (idx, child) in children.pos().enumerate() {
            only(start + idx, box(
                width: max-width,
                height: max-height,
                align(position, child)
            ))
        }
    })
}

#let line-by-line(start: 1, body) = {
    let items = if repr(body.func()) == "sequence" {
        body.children
    } else {
        ( body, )
    }

    let idx = start
    for item in items {
        if repr(item.func()) != "space" {
            uncover((beginning: idx), item)
            idx += 1
        } else {
            item
        }
    }
}

#let pause = raw(
    "PAUSE SIGNAL",
    block: false,
    lang: "terrible hack"
)

#let _parse-pauses(body) = {
    let find-pauses-sequence(seq) = {
        seq.children.enumerate().filter( idx-item => {
            let (idx, item) = idx-item
            item == pause
        }).map(idx-item => {
            let (idx, item) = idx-item
            idx
        })
    }

    let split-sequence-at-pauses(seq) = {
        let pause-idcs = find-pauses-sequence(seq)
        pause-idcs.insert(0, 0)
        pause-idcs.push(seq.children.len())

        let chunks = ()
        for i in range(pause-idcs.len() - 1) {
            let lo = pause-idcs.at(i)
            let hi = pause-idcs.at(i + 1)
            chunks.push(
                seq.children.slice(lo + 1, hi)
            )
        }
        chunks
    }


    let items = if repr(body.func()) == "sequence" {
        let chunks = split-sequence-at-pauses(body)
        chunks.map(chunk => {
            for thing in chunk {
                thing
            }
        })
    } else {
        (body,)
    }

    for (idx, item) in items.enumerate() {
        uncover((beginning: idx + 1), item)
    }
}

#let slide(
    max-repetitions: 10,
    theme-variant: "default",
    override-theme: none,
    ..kwargs,
    body
) = {
    pagebreak(weak: true)
    logical-slide.step()
    locate( loc => {
        subslide.update(1)
        repetitions.update(1)
        pause-counter.update(1)

        let slide-content = global-theme.at(loc).variants.at(theme-variant)
        if override-theme != none {
            slide-content = override-theme
        }
        let slide-info = kwargs.named()
        let paused-body = _parse-pauses(body)

        for _ in range(max-repetitions) {
            locate( loc-inner => {
                let curr-subslide = subslide.at(loc-inner).first()
                if curr-subslide <= repetitions.at(loc-inner).first() {
                    if curr-subslide > 1 { pagebreak(weak: true) }

                    slide-content(slide-info, paused-body)
                }
            })
            subslide.step()
        }
    })
}

#let slides(
    title: none,
    authors: none,
    subtitle: none,
    short-title: none,
    short-authors: none,
    date: none,
    theme: slides-default-theme(),
    typography: (:),
    body
) = {
    if "text-size" not in typography {
        typography.text-size = 25pt
    }
    if "paper" not in typography {
        typography.paper = "presentation-16-9"
    }
    if "text-font" not in typography {
        typography.text-font = (
            "Inria Sans",
            "Libertinus Sans",
            "Latin Modern Sans",
        )
    }
    if "math-font" not in typography {
        typography.math-font = (
            "GFS Neohellenic Math",
            "Fira Math",
            "TeX Gyre Pagella Math",
            "Libertinus Math",
        )
    }

    set text(
        size: typography.text-size,
        font: typography.text-font,
    )
    show math.equation: set text(font: typography.math-font)

    set page(
        paper: typography.paper,
        margin: 0pt,
    )

    let data = (
        title: title,
        authors: if type(authors) == "array" {
            authors
        } else if type(authors) in ("string", "content") {
            (authors, )
        } else {
            panic("authors must be an array, string, or content.")
        },
        subtitle: subtitle,
        short-title: short-title,
        short-authors: short-authors,
        date: date,
    )
    let the-theme = theme(data)
    global-theme.update(the-theme)

    the-theme.title-slide
    body
}
